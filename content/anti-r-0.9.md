+++
title = "anti-r published"
date = 2021-02-03
[taxonomies]
tags = ["rust"]
categories = ["anti-r"]
+++

[anti-r](https://crates.io/crates/anti-r) is a spatial data structure that can outperform R-Trees in many cases.

<!-- more --> 

## Intro

In a multi-year research effort in a secret government underground bunker
my team and I developed a bleeding edge data structure
that can outperform the obsolete state-of-the-art spatial data structure, R-Trees, in many cases.

This will be a very theory heavy blog post, introducing the [research paper](https://www.youtube.com/watch?v=dQw4w9WgXcQ).
Readers are advised to have at least a bachelors,
preferably a master degree in computer science.

## Data Structure

The fancy new data structure is... a sorted slice.

Sorted lists are a representation of a binary search tree.
They therefore have the same O(n) complexity on all operations as R-Trees:
n\*log(n) for creation,
log(n) for searches.

They even have the same nice property of devoting more "focus" to denser regions,
simply because each element occupies exactly one slot.

In fact one of the first steps when creating a high-quality R-Tree is to sort the input.
This crate simply skips the next step of building an R-Tree from the implicit binary tree.

## Performance

The benchmarks included in this repository suggest that
this approach (obviously) beats R-Trees on creation
and on full updates for any number of elements.
More interestingly it also beats query performance for up to 100\_000 elements.
Starting at around 200\_000 elements R-Trees start winning.
I suspect that's the point at which the data does not fit into L1-cache any more
and starts incurring the same cache-misses from indirection that R-Trees do.

## Drawbacks

Besides being slower for a large number of elements,
anti-r only supports points as geometry primitives.
If you want to, for example, insert triangles you will have to
manually decompose them into their outermost points and insert those.

## Outro

So if you are doing spatial queries on a medium number of elements,
or chunk your elements into medium-sized chunks for progressive loading etc.,
this crate might be for you. Or you can just... use a sorted Vec I guess.

This crate is no\_std, with an alloc feature enabled by default.
The alloc feature enables the SpatialVec, without it only SpatialSlice is available.


[crate](https://crates.io/crates/anti-r) [docs](https://docs.rs/anti-r/) [repository](https://github.com/djugei/pixelherd/tree/main/anti-r)
