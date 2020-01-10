+++
title = "Why I like programming for #![no_std] in Rust (even without embedded)"
date = 2020-01-10
[taxonomies]
tags = ["rust", "no_std"]
categories = ["misc"]
+++

I noticed that I quite enjoy writing libraries that support no_std environments,
even though I myself don't even work on embedded.

<!-- more -->

Its just very fun to try and get as many features done without ever allocating, purely from a challenge point of view.

There is also some benefits one can hope for, the two big ones being usability in more cases, like embedded,
and better performance due to less memory management overhead, possibly less indirection and therefore more
compiler insight


After a bit of thinking I realized that there is one more, and much more fundamental issue:
If im not mistaken Rust without allocations is not [Turing complete]() (for the most part).


## What is Turing complete
Basically a Turing machine can solve any problem that we know how to solve at all.
A language that is Turing complete is to some degree equivalent to a Turing machine,
i.e. can be transformed into one without gaining or loosing functionality.
Most programming languages, including Rust, are Turing complete.

Computer science can also reason about "über Turing machines" that can solve problems even Turing machines can't solve,
but we have no idea how to build one of those even in theory.

While being most powerful, Turing complete languages also have some drawbacks.
They are harder to reason about than their lesser peers.
For examples its impossible to tell if a given program is going to run into an endless loop/recursion.


## Dual stack automata and Rust
Dual stack automata are constructs that are exactly as powerful as Turing machines.
They are finite automata that also have access to two separate stacks.
As soon as you have two stacks you can build any kind of data structure, including any number of stacks.

You can consider normal Rust to be one of those. You have the code as the automaton,
the call stack as one stack and stuff on the heap as the second stack.

Now no_std, or more specifically Rust without allocations lacks the second stack.
Its therefore (mostly) a (single) stack automaton.
As such its strictly less powerful than allocating Rust, i.e. there exist problems that can be solved in allocating Rust, but are
impossible to express in alloc-free Rust.

Because many tasks actually do not require a Turing machine to solve,
actually solving them on a l less powerful machine is a fun challenge and I think that is why I like it.


## (mostly) a single stack automaton?
How can something be mostly a single stack automaton?
Well for one no programming language is actually like _really_ _really_ Turing complete.
A dual stack (and even a single stack!) automaton requires two (one) unbounded stacks.

Unbounded as in as large as the problem needs it to be. Real computers have limited hard disk space though, so they fail that
requirement for big problems. And in practice fail it even for much smaller problems cause no one wants to use Disk as Memory.

In the same way you could have a second, bounded, stack be an element in your single stack and therefore have "two" stacks.
But at this point you are basically building an allocator anyway :).

Also no_std and alloc free Rust still allow for infinite loops and recursions. That's true but basically never a good idea.
Since you only have one stack, that at any point has a known number of elements it basically never makes sense to iterate over
anything without bounds.

I might also have overlooked some other loophole, just send a [pull request](https://github.com/djugei/djugei.github.io/tree/raw)
 with your nit picks.
There might also be something wrong with my understanding of the computer science, feel free to correct.

Add your comments on [reddit]()!
