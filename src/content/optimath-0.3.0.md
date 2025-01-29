+++
title = "Optimath version 0.3.0 released"
date = 2020-01-13
[taxonomies]
tags = ["rust"]
categories = ["optimath"]
+++

Optimath is an experimental const generics based linear algebra library that works without any allocations in no_std and utilizes simd.
So now you can do fancy maths on embedded.

<!-- more --> 

## Intro
This library is based around one type, [Vector](https://docs.rs/optimath/0.3.0/optimath/struct.Vector.html) that passes on element-wise operations (+-\*/) to its contained elements.
Vectors have a size that is known at compile time thanks to const generics.

```rust
// Vectors can be initalized from an rng,
let a: Vector<i32, 2000> = rng.gen();
// from iterators
let b: Vector<i32, 2000> = (0..2000).collect();
// with an initalizer function
let c: Vector<i32, 2000> = Vector::build_with_fn(|i| i as i32);
// or using Default
let d: Vector<i32, 2000> = Default::default();

let e = &a + &b;
let f = &c + &d;
let h = &e + &f;
```

A [Matrix](https://docs.rs/optimath/0.3.0/optimath/type.Matrix.html) is therefore just a Vector\<Vector\<T\>\>,
but has specific methods, namely transpose and matrix_multiply implemented on it.

```rust
use optimath::Matrix;
let a: Matrix<f32, 2, 3> = Default::default();
let b: Matrix<f32, 3, 4> = Default::default();

// matrix size is checked at compile time!
let c: Matrix<f32, 2, 4> = a.matrix_multiply(&b);

// transpositions are just views on matrices.
// can be materialized on demand
let c2 = c.transpose().materialize().transpose().materialize();
assert_eq!(c, c2);
```

You can find a lot of further information in the [README](https://github.com/djugei/optimath/blob/master/README.md).

I have been mostly concerned with library design,
if you need any specific operation please feel free to open an [issue](https://github.com/djugei/optimath/issues) (or a pull request of course).


## Specialization
Optimath not only uses const generics, but also specialization, for the full type adventure experience.

There has been an [issue](https://github.com/rust-lang/rust/pull/67906) that stopped you from calculating array sizes at compile time.
A lot of this crates further development has been blocked on that.
This issue has luckily been resolved by now, but the docs of version 0.3.0 still refer to it.
You will therefore need quite a recent nightly to compile version 0.4.0 and onwards.

Specialization is then used to override the generic pass-trough operations (+-\*/) for specific types, like Vector\<f32\>.
On those instead of doing element-wise addition SIMD can be used.
Or at least that is how I initially did it.
Checking the assembly (shoutout to [cargo-asm](https://github.com/gnzlbg/cargo-asm)) I noticed that rustc/llvm already did perfect SIMD,
especially with the help of explicit alignment.
Doing some [benchmarks](https://github.com/djugei/optimath/blob/master/benches/simd.rs) showed no gain from manually re-implementing that.

They still need to pack/unpack &[f32; 4] into one simd-register though.
The next step is therefore to just always store the types in an SIMD compatible way.
That had been blocked on the aforementioned issue.
Some experimentation can be found in the (disabled) [layout module](https://github.com/djugei/optimath/blob/master/src/layout.rs).


## Purpose
I started this library because there was no no_std capable linear algebra library available and I wanted to move move [dumbnet](/categories/dumbnet) away from GenericArray now that const generics are available in rust.
So the initial purpose of optimath was to fit my personal usecase.

One possible direction is to make this the base of a rust BLAS library, there is a detailed planned changelog in the [README](https://github.com/djugei/optimath/blob/master/README.md).

Its also intended as a playground and an exploration on how a const generics may be adapted in a linalg crate.
I would be perfectly happy to merge this with for example ndarray at some point.

Additionally it might be a motivating example for the rust devs working on const generics and specialization,
showing off some real usecases. And finding compiler bugs, ofc :).

For both of those groups there is some takeaways in the [insights module](https://docs.rs/optimath/*/optimath/insights/index.html).


## no_std notice
no_std users will have to comment out the dev-dependencies cause they seem to be polluting the real ones.
i do not know how to turn that off sadly. With them commented out
```bash
cargo build --target=armebv7r-none-eabihf --release
```

builds without errors. If anyone knows how to fix that don't hesitate to contact me!

[crate](https://crates.io/crates/optimath/) [docs](https://docs.rs/optimath/) [repository](https://github.com/djugei/optimath)

You can also join the discussion on [reddit](https://www.reddit.com/r/rust/comments/eo4ury/)!
