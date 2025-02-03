+++
title = "Treelike version 0.2.0 released"
date = 2019-07-20
[taxonomies]
tags = ["rust"]
categories = ["treelike"]
+++

Treelike is an abstraction over Trees, kinda like Iterator for lists. Is also no_std by default.


<!-- more --> 

When implementing trees in multiple projects I noticed myself re-implementing the same kind of methods over and over again.
That is why i made [Treelike](https://crates.io/crates/treelike), my first crate.

It contains a Trait, Treelike, that asks you to implement two methods, content() and children() on your node-type.
Many kinds of traversals are then provided for free.


A side-effect of that is providing a common Trait for tree-types, allowing simpler switching of implementations and maybe even further abstractions on-top.

The entire crate is no_std-compatible. It optionally and by default uses the alloc crate. Without the alloc-feature you get callback-based iterations,
with it you additionally unlock the Iterator-based iterations.

I am publishing it here hoping that some people might find it useful and to get some feedback.

[crate](https://crates.io/crates/treelike) [docs](https://docs.rs/treelike/0.2.0/treelike/) [repository](https://github.com/djugei/treelike)

Let me know what you think on [reddit](https://www.reddit.com/r/rust/comments/cfn0u2/)!
