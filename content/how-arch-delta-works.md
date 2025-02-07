+++
title = "How arch-delta Saves 80+% Of Bandwith On Upgrades"
date = 2025-01-20
draft = true
[taxonomies]
tags = ["rust"]
categories = ["arch-delta"]
+++

[arch-delta](https://github.com/djugei/arch-delta-upgrades/) upgrades arch installations
using ~83.75%* less bandwidth by only downloading the difference between package versions.

<!-- more --> 
This post is more of a technical overview, for people interested in programming and rust.
Read the [sister post](../arch-delta-released) if you want to know what this is about or you use arch btw.
I will give an overview of the project.
If people are interested I might do deeper dives into some aspects in later posts.


## History/Timeline
Arch Linux's package manager pacman used to have a built-in delta upgrade.
This was discontinued around 2019 due to
  [security concerns](https://security.archlinux.org/CVE-2019-18183),
  implementation complexity
  and a perceived lack of usage.

There was only one server really providing deltas,
  if memory serves me right, it only provided deltas between directly adjacent versions.
It was based on the xdelta3 tool/algorithm.

I was an avid user of that feature, due to my very slow internet connection.
So in 2023 I started working on a replacement.
I have been using it for more than a year now and it feels ready for release.


## Design
I decided on a slightly different approach for my project.
For one the underlying delta algorithm is ddelta,
a continuation of bsdiff which itself noticeably outperforms xdelta3.

The server generates deltas on demand instead of pre-generating them, leading to a 100% hit rate,
  though at the cost of some delay for the first client.

Instead of signing the deltas and introducing an additional trusted party,
  the packages are recreated in a bit-exact manner on the client
  and pacman's regular signature checking can be utilized.

The client wraps pacman instead of instead of being more tightly integrated,
mainly to provide user-friendly progress indicators while working on multiple packages in parallel.

Rust alleviates at least some of the common security concerns.
Additionally the Arch Linux project does not have to shoulder any additional complexity.

### Alternatives
Pre-generating the most common and most compressible packages and communicating them to the client as a whitelist
  would allow a somewhat simpler design.
The client gets called for each dependency (XferCommand)
  and either does the delta download or gets the package from the mirror.
This would potentially loose a lot of the long tail.
While ~50% of the size savings are found in the top 10 packages,
  it required generating a lot of deltas to _find_ those top 10 packages.

A solution to that may be a hybrid approach where the server supports both styles and the user can choose.


## Development tricks
Before getting into the details,
  let me share some things that helped get this project done.

### Small todo notes.
If you check the ```.gitignore``` you may find that files called todo are excluded.
Whenever I did not have time or motivation and noticed
  a feature needs to be done,
  nontrivial bug needs to be fixed,
  or design needs to be changed,
I put it in there.
Then either noticed that some part of the todo could be done right away,
  or I would simply pick up a task the next time I came back.
Small bugs or things related to only a specific section on the code I put into ```rust //TODO:``` or ```rust //FIXME:```comments.
No need to be consistent,
  just do what helps.

### Just fork it
Sometimes your dependencies don't quite work the way you like them to,
  or they may be lacking a feature.
I have pretty aggressively forked the dependencies,
  implemented the change
  and switched to relying on my own repository.
I have then generally opened a PR in the upstream repository.

This way you don't get blocked and the upstream project potentially gains a feature.


## Server
The server has to:
  * Accept a request for a delta from an old to a new version
  * Get base packages from regular arch mirrors
  * Calculate deltas between old and new
  * Serve the delta to the client

To avoid wasting resources packages and deltas are cached between requests.
To efficiently utilize the servers available resources,
  multiple things are done concurrently using async.

### Get
This is mostly a simple download, limited by a semaphore to not overload the connection.
Arch Linux mirrors only carry the most up-to-date package,
  but there is a high likelihood of old package being cached from the last update.
In any case the [Arch Linux Archive](https://wiki.archlinux.org/title/Arch_Linux_Archive) is used as a fallback.

I found the headers crate to be a bit lacking. For example the ContentDisposition header only allows partial construction and no parsing.
Luckily the [ruma](https://github.com/ruma/ruma) project has an implementation that I simply copied over.
Also there is pretty bad integration between reqwest and the headers crate.
It seems to require building a one-entry HeaderMap which can then be inserted into the reqwest request.

### Delta
The juicy bit, but mechanically also relatively simple.

Once the old and new packages are available they get decompressed,
  since generating deltas on compressed things is a futile endeavor ([foreshadowing](../arch-delta-released#Issues)).
The decompressed packages are passed into [ddelta-rs](https://lib.rs/crates/ddelta),
  limited by a semaphore to not overload the server.

Delta generation uses a lot of CPU time and a lot of memory.
While counting the number of cores is pretty simple,
  limiting for memory is not.
Each delta uses an amount of memory linearly related to the uncompressed package sizes,
  which are wildly different and unknown before decompression.
The current tactic is to just hope enough memory is available and hit swap in the worst case.
Since decompressed packages are highly compressible,
   tools like zswap and zram can be viable mitigations.

Delta generating is spawned as an independent task with a backchannel,
  to avoid wasting work when a request times out.

### Cache
The most complex part of this project was to get a (hopefully) correct cache.
As no existing caches I found met my requirements:
  * On-Disc cache
  * Manual cache expulsion
  * Readable filenames

I had make my own.

The Cache holds a Mutex-protected HashMap.
Each Entry contains the cache-key and a broadcast channel.

The basic flow is:
  1. Lock HashMap
  2. Check if an entry exists for the value we need
  3. If none exists check on Disc if the file exists,
  4. If none exists add an entry to the HashMap and start generating
  5. Drop Lock
  6. Finish generating, send message, remove the entry

If in step 2 the Entry exists,
  we simply wait for a message on the chanel and read the file afterwards.

Generating the File might fail.
In that case the generating task simply fails,
 while all other waiters restart the basic flow.
One of them turns into the new generator,
  the others resume waiting.

The generator writes into a temporary file
  that only gets renamed to it's permanent name
  after successful generation
  to avoid step 3 finding a garbage file.

I used Hashbrown as my HashMap implementation of choice.
To save on a copy bound on the Key I have slightly [extended their entry API](https://github.com/rust-lang/hashbrown/pull/579),
  allowing users to provide the owned Key at insertion instead of at query time.

#### API
```Cacheable``` types hold the State,
  if any is needed,
  for example a handle to a http-client,
  or a name/path to differentiate instances.
They need to provide two functions,
  one that turns a cache key into a filesystem path,
  and one that generates the File.

In the first iteration those were provided as loose functions to the ```FileCache```.
While this allowed the same type to be cached differently in different places
  it made the types *horrible* and generally unnameable.

The current iteration requires the implementation of a trait,
  that covers those functions leading to a much more usable interface.
The type look much nicer now too, as the Key and Error are associated types now,
  therefore disappearing from the type signature.

### Async
Since I wanted to use computational and network resources in parallel
  some manner of concurrency was required.
I needed an HTTP-server
  and most frameworks are async-based,
  so I chose async over threads.

This is a choice I have now come to regret.

For one,
  since the requests that actually calculate the deltas are computationally intensive,
  I end up spawning threads anyways.

Choosing async in practice means choosing tokio
  because the rust stdlib does not provide sufficient async functionality out of the box,
  leading library implementer towards writing runtime-specific code.
The cache I implemented for this project now depends on tokio,
  as I needed to spawn a blocking task and use an async-aware mutex.
If rust is serious about async support it needs to have good defaults.
This means either integrating tokio into the standard library
  or actually providing a set of Traits and types for interoperability and abstraction. 

The debugging experience was also … not great.
(anyhow-)backtraces are now horrible and contain 200 lines of tokio-related spam.
Luckily that's more of a nuisance since I did not have too many crashes overall.

More importantly here is a memory leak I can not track down.
After serving a few requests the server keeps using 500MB in idle.
I am reasonably sure that no data structure I introduced grows unbounded.
Though tools to find the (recursive) memory use of a struct are very lacking.
I used heaptrack and bytehound,
  but did not find useful information in their output.
Libraries
  that instrument your code to provide a ```size_in_mem``` function
require recursively deriving a trait on all structs you are interested in.
Since you can not implement foreign traits on foreign types,
  the libraries would have to provide trait implementations on all your dependencies.
An impossible task.
I assume that the issue is somewhere in the framework or the runtime.
No idea where and how to debug this though.

Overall I will probably re-engineer the server to use some purely threaded solution.
That also means rewriting the cache,
  though the logic stays the same,
  so I am hoping that just removing the async/await keywords will do the trick.


## Client
The client has to:
* Check for new packages
* Check for existing old packages to use as a delta base
* Send requests to generate/download deltas
* Wait for deltas to be generated
* Download deltas
* Patch packages
* Re-compress packages to provide bit-identical versions for signatures
* And show a responsive, informative user interface.

The client also uses async, though somehow it felt way better than on the server.
Most steps are quite straightforward.
Semaphores are used to limit the degree of parallelism to not overload the client or server.

```pacman -Sy``` is used to check for new packages (though see [Database Deltas](#database-deltas) for recent developments),
```pacman -Sup``` gives a list of upgrade candidates.

A dirwalk through the cache directory finds available old packages.
to catch packages being renamed there is some string similarity matching if exact matches could not be found.

The server might take a while to generate packages,
  or unreliable connections could cancel a download,
so retry and resume logic has been put into place.
Only one download is done at a time,
  to not overload the connection.

Since the signatures of packages are generated on the compressed files
  it is necessary to recompress with the exact same parameters.
I was unable to call the zstd library in the correct way,
  so I spawn process of the zstd command line tool.
Thankfully that provides reproducible results.

### Bit-exact reproduction
Compression requires the exact same version of zstd and the exact same parameters.
Since I deem juggling multiple versions of zstd to be out of scope
  this results in some unpleasantness around zstd upgrades.
This is made somewhat worse by arch "stable" packages sometimes being built within a "testing" environment.
Additionally packages can in theory alter the zstd compression parameters,
  though to my knowledge only one package does.
Ironically that is [the rust package](https://gitlab.archlinux.org/archlinux/packaging/packages/rust/-/issues/4),
  for a net size save of 647 bytes.

A solution for this is to have signatures on the uncompressed packages.
arch-delta is specifically designed not to be trusted,
  so rolling my own signing infrastructure is not in the cards.
I hope to be able to convince the arch developers to provide uncompressed signatures
  in addition to the compressed ones,
  once this approach is shown to be useful.
This also has the advantage of skipping the recompression step which is generally pointless,
  as the packages get instantly installed anyways.

### Signatures
While Pacman automatically downloads missing signatures, it does so in a sequential manner,
  which takes a noticeable amount of time due to all the roundtrips involved.
As async makes this quite simple we also download all signature files concurrently.

### UI
Since a package can be in one of 4 states (waiting, downloading, patching/compressing, error)
  and a lot of packages are processed concurrently
  and the entire process takes quite a bit of time,
  its necessary to provide the user with feedback,
  otherwise they grow impatient.

I chose to show progress for currently running tasks,
  as well as printing a log of events to the terminal.

This is implemented using [indicatif](https://lib.rs/crates/indicatif) for the progress bars
  and the [log](https://lib.rs/crates/log) crate with [env_logger](https://lib.rs/crates/env_logger) for the log.
Since those two sometimes fight for the terminal,
  I created [indicatif-log-bridge](lib.rs/crates/indicatif-log-bridge),
    a surprisingly popular crate,
  that makes them play nice.

People generally want to know
1. Whats happening
2. How long its gonna take
3. Why something happened,
   especially if something goes wrong
4. If something was worth it

Progress bars are a great tool for 1.) and 2.),
but getting accurate etas is not easy,
  especially with tasks of wildly different sizes.
I show a progress bar per running task,
  and a big overall one.

I made sure the server included the content-length header
  so the download phase can be accurately displayed/predicted.
The patching/compressing phase is slightly harder,
  for one neither the patch, the old version, or the new version get accessed in a linear manner.
I built some [heuristics](https://github.com/console-rs/indicatif/pull/657) for that but its not perfect.
Additionally there is a black box compression phase which is handled by an external tool.

The overall progress bar uses the estimated decompressed sizes of the old packets
  and gets incremented by half the size after the download and patching phases finished.
Since Arch Linux packages get compressed on the fly,
  by piping them into zstd and piping the output into a file,
  the header can not be fully populated
  and only full decompression can give a precise measure of decompressed size.
There is an estimation function available that generally massively overestimates.
Since the absolute size is not as important as the relative sizes of the packets,
  that is something I just accept,
  and communicate to the users.

Potential improvements are to figure out the correct compression parameters,
  remember relative speed of network and compute on the users computer,
  and a rough estimation of patch creation duration on the server.
Those changes are somewhat low priority though.

To explain why something happens I write a long message a non-default path is taken.
This is generally either the package being on the blacklist due to know bad delta compression performance,
  or no previous package of that name being available in the package cache,
    usually because of package renames or ```pacman -Scc```.

\* the efficiency described in the opening paragraph is with linux-image blacklisted,
  due to very low gains and long calculation.
  It also only covers hits,
    ignoring uncaught renames,
    newly introduced dependencies,
    and the user simply not having the previous version in cache.

To give efficacy feedback the tool outputs bandwidth saved in the end of each run,
  and provides a "stats" subcommand that calculates statistics by scanning the package cache.


## Database Deltas
Part of the bandwidth for updates is used to find which updates are available ```pacman -Sy```.
As the bandwidth for downloading packages was massively reduced by deltas the database sync became relatively more relevant.

So I added delta updates for databases.

Works very similar to deltas for packages, except for databases lacking versions.
So I made the name a version at most once every 10 minutes,
  but only if the upstream database actually changed.
This way the client can tell the server which version it has,
  and the server can reply with a delta to the newest version,
  including the newest versions name.
The server _should_ always have the old version,
  since that was served to the client the last time.

This works really well,
  generally saving 99+% of bandwidth.

This feature is not as well tested as the rest of the software, so it can be disabled.
