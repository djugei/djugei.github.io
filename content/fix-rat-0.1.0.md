+++
title = "fix-rat published"
date = 2021-01-23
[taxonomies]
tags = ["rust"]
categories = ["fix-rat"]
+++

[Fix-rat](https://crates.io/crates/fix-rat) is a rational number with a denominator chosen at compile time.

<!-- more --> 

While working on a different project
I found a need for a number type that is kinda like floats.
It needs to do maths and represent numbers in smaller increments than one
but also had the important requirement of having associative operations,
so a + b + c == a + c + b in every case.

This might seem like a simple request and
you might even be surprised why this is even mentioned,
after all that is simply how numbers work, right?

Sadly floats can not satisfy that property
since their rounding behaviour is a bit surprising,
especially around numbers with different exponents.

The already existing crate [num-rational](https://crates.io/crates/num-rational) is also not very usable,
as it panics whenever it looses precision and does a huge amount of calculation to re-normalize itself
(turning 2/10 into 1/5)
even on mundane operations .
This is required though to get proper equality operations and not continuously "bloat" the number(s).

So I made [fix-rat](https://crates.io/crates/fix-rat).
It utilizes const-generics to basically re-scale integers from i64::MIN..i64::MAX to whatever range you desire.

```rust
use fix_rat::Rational;
type R = Rational<{ i64::MAX / 64}>;

let a: R = 60.into();
let b: R = 5.0.into();
let c = a.wrapping_add(b);

let c = c.to_i64();
assert_eq!(c, -63);
```

The code is not very complex, but someone had to write it :).
The [documentation](https://docs.rs//fix-rat/) contains some useful tips
on how to handle numbers in multithreaded scenarios
without loosing determinism.

I hope the code is as useful to someone else as it is to me.
Open an issue if use-case 4 from the documentation
(one- or two-byte floating point numbers) is relevant to you.

[crate](https://crates.io/crates/fix-rat) [docs](https://docs.rs/fix-rat/) [repository](https://github.com/djugei/pixelherd/tree/main/fix-rat)
