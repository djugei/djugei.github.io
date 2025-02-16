+++
title = "arch-delta project release v0.5"
date = 2025-02-16
draft = true
[taxonomies]
tags = ["rust"]
categories = ["arch-delta"]
+++

[arch-delta](https://github.com/djugei/arch-delta-upgrades/) upgrades arch installations
using ~83.97%* less bandwidth by only downloading the difference between package versions.

<!-- more --> 
This is a beta release post aimed at arch users on low bandwidth or metered connections.
Read the [sister post](../how-arch-delta-works) if you want to know how its made.

## Background/History
pacman used to have a delta mode.
It was discontinued around 2019,
  so I started making my own.
I have been using it for a year now,
  and it works well,
  so I am releasing it for others to benefit too.

## Installation/Setup/Usage
Install [```deltaclient```](http://aur.archlinux.org/packages/deltaclient) from the AUR,
then run:
```sh
sudo deltaclient upgrade http://bogen.moeh.re/  
```
This will synchronize databases,
  download deltas,
    and where no prior version is cached,
  downloads packages from the mirror.
Afterwards it runs pacman to install the upgrades.
So basically it replaces ```pacman -Suy```.

Since deltas are generated on first access the "server generates" phase might take a while.

If you do not enjoy watching the pretty progress bars you can run
```sh
# for setup
sudo systemctl enable deltaclient.timer

# for one boot/run
sudo systemctl start deltaclient.timer
sudo systemctl start deltaclient.service

# to actually run the upgrade
sudo pacman -Su # no -y
```
This will regularly check for updates and download delta upgrades into the package cache.
It will not download regular upgrades to not put undue stress on the network connection.
Then just run ```pacman -Su``` (note the lack of ```-y```) whenever you want to upgrade your system.

## Usage tips
- *DO NOT EVER* run ```pacman -Scc``` (one ```c``` is fine).
arch-delta needs a locally cached version of a package to build the delta off of.
No local package, no delta.

- Check ```deltaclient download``` for a way to run the deltaclient as a regular user,
  without requiring root, and therefore no trust in me!

- When the zstd package is updated or about to be updated signatures may not match for a few days.
  You can try switching between the regular, testing, and old versions.
  Note that even the regular arch packages are sometimes built using the testing version of zstd.

- You can set ```RUST_LOG=deltaclient=debug``` to get more detailed output.

## How well does it work?
Pretty well.
83.97%* bandwidth savings for packages,
97+% for databases means I can keep my system up to date without interrupting my internet use.

As a comparison, regular (zstd) compression saves 71% over uncompressed packages.
arch-delta saves 83.97% of the compressed bandwidth,
resulting in 95+% total saves over uncompressed packages.

The initial wait for the server to generate the package and for the client to re-compress it
are a bit annoying, but the timer/service work around that nicely.

The \* in the numbers refers to the linux package being blacklisted while recording the stats.

## Status of components/Future plans
Overall it works pretty well.
The functionality is there,
  just some places are still a bit rough.
The code is a bit of a mess but is actively being worked on.
### Package deltas
Status: pretty good.

I have used this for a year and it works well.

There are two pain points left,
though they are a bit outside of the scope of the project itself,
I hope to work on a solution to them in cooperation with the Arch Linux developers.

Deltas are calculated on the uncompressed packages.
The client then needs to re-compress the packages with the exact same (very high) settings
to match the package signature.
* wastes time on the client
* Pain around zstd updates
* Packages can in theory set their own compression parameters,
  making reconstruction fail
  though in practice only one maintainer does so (they are special cased).

A good solution to this would be for the arch maintainers to also provide a signature for the
uncompressed package.

A bad solution would be me distributing those signatures.

The ```linux``` package specifically is badly compressible _and_ badly delta-compressible
as all kernel modules are individually compressed inside since 2008.
Distributing uncompressed kernel modules would save about 30MB on regular packages and 80MB for deltas.

Possibly the package can be modified to not compress modules and instead optionally compress them post-install.
Though I have less hope of the Arch Linux developers accepting that change,
modern filesystems having transparent compression built-in is a pretty good argument.

### Database deltas
Status: newer but promising.

I have used this for about a month an it works well.
Due to only a few packages out of the entire database changing each time
  the relative bandwidth savings are also pretty sweet.

deltaclient can't currently run database syncs as non-root user,
the next version should be able to.

### Regular package download
Status: pretty new

I mainly added this to fill the time otherwise spent waiting for delta generation.
Its pretty new but also quite simple and seems to work well so far.

