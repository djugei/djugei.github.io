+++
title = "Dumbnet version 0.1.0 released"
date = 2019-12-26
[taxonomies]
tags = ["rust"]
categories = ["dumbnet"]
+++

Mostly for fun I developed a small artificial neural network library that does all its work on the stack, no operating system or allocator needed.

<!-- more --> 

It works by, at compile time, building the networks Type layer by layer from output to input.

I based it off of GenericArray back when const generics were not a thing yet in rust. Its a nice hack but produces some... [interesting trait bounds](https://github.com/djugei/dumbnet/blob/master/src/convolution.rs#L15-L62). I intend to move this to something const generics based step by step to showcase how much nicer things can look nowadays.

(also found a bug in rustfmt, were those comments doc-comments rustfmt would join the next line into them, breaking the code)

Its not super complex right now, but is able to solve classification problems quite well. Play around with it a bit if you like, just add it as a dependency and go, no further setup required!

I am always open for feedback or contributions.

[crate](https://crates.io/crates/dumbnet/) [docs](https://docs.rs/dumbnet/) [repository](https://github.com/djugei/dumbnet)

Let me know what you think on [reddit](https://www.reddit.com/r/rust/comments/efwvzu/)!
