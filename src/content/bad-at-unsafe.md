+++
title = "Im bad at unsafe {}"
date = 2020-05-12
[taxonomies]
tags = ["rust"]
categories = []
+++
I tried writing a Chunked-List data structure and made all the mistakes while using unsafe for that.

<!-- more --> 

I have always avoided C and C++ because I knew I could not be trusted with Pointers.
Rust allows me to keep the high risk code contained into small unsafe { } sections.
I want to write down what mistakes I made inside those sections and how I caught them.
My next blog post will be about the data structure.

## Not reading the docs
At first I just assumed that the .add() and .offset() methods on pointers would mutate the pointer.
They do not.
Instead they return a new pointer,
  which gets dropped silently if you don't use it.
Unlike for example Result, which is must\_use annotated.

```rust
// wrong code:
let mut buf = [1, 2];
let ptr = &mut buf[0] as *mut u8;
unsafe { ptr.add(1) }
// ptr still points to the first element, with no warnings
```

```rust
// better code:
let mut buf = [1, 2];
let ptr = &mut buf[0] as *mut u8;
let ptr = unsafe { ptr.add(1) }
```

I caught that because I had tests and they failed.

So turns out that "better" is not good enough!
The pointer points to the first _element_
and while going one past the element is not UB,
using it would be.
We need a pointer to the whole array if we want to move around in it.
```rust
// correct? code:
let mut buf = [1, 2];
let ptr = buf.as_mut_ptr();
let ptr = unsafe { ptr.add(1) }
```
Pointed out by [CAD1997](https://www.reddit.com/r/rust/comments/gide2n/im_bad_at_unsafe/fqeg7vb/).

## Alignment-issues
In the data structure I was building each chunk would have
a fixed size/capacity and link to the next chunk.
The basic data structure is, assuming 64 bit,  defined as:
```rust
pub struct Chunk<T> {
    buf: [u8; 4096 - 2 - 8],
    len: u16,
    next: Option<Box<Self>>,
    phantom: PhantomData<T>,
}
```
For initialization I wanted to just pass in a page of memory and write to it
```rust
fn new<T>(base: [u8; 4096]) -> Chunk<T> {
	// ...
}
```
Simple right?
Well not so fast.

An array of u8 has an alignment of 1, meaning it can start on any byte of memory.
But the chunk's len field has an alignment of 2, can only start on even bytes.
The next field even has an alignment of 8.
I solved that my requiring the user to pass in an uninitialized chunk that - by definition -
fits the required alignment:
```rust
fn new<T>(base: MaybeUninit<Chunk<T>>) -> Chunk<T> {
	// ...
}
```
I caught this using miri.
The new function signature makes getting a Chunk a bit more annoying for the user.
But at least its safe now.

Right?

Well no. Right now Chunk has an alignment of 8.
What if we want to store something with a bigger alignment?
Segfaults, thats what.
```rust
#[repr(C, align(4096))]
pub struct Chunk<T> { }
```
Now its force-aligned to a full page.

This one I actually caught on my own due to thinking about the previous alignment error.

But wait, there is more!
We also need to consider the case of T being bigger than the buffer,
or having an alignment even larger than a whole page.
Sadly at the moment its not very viable to check this at compile-time,
so runtime-checks will have to do.

```rust
fn new<T>(base: MaybeUninit<Chunk<T>>) -> Chunk<T> {
        assert!(std::mem::size_of::<T>() <= BUF_SIZE);
        assert!(std::mem::align_of::<T>() <= 4096);
	// ...
}
```

Now we are good. I hope.

## Off-By-"One"
In the wonderful world of safe rust, everything is done with iterators
and actually indexing anything is a rare sight.
In fact I have come to basically never use manual indexing or offsets in my code.
A bit like a mathematician, seeing actual numbers just feels wrong.

In unsafe rust you will need to manually count with pointers.

### Pointer Casts

The first mistake I made was actually in safe code, producing a value I then wanted to use in an unsafe block:

```rust
fn new<T>(base: MaybeUninit<Chunk<T>>) -> Chunk<T> {
        assert!(std::mem::size_of::<T>() <= BUF_SIZE);
        assert!(std::mem::align_of::<T>() <= 4096);
	let base_ptr = base.as_mut_ptr();
	// skip to len field:
	let len_ptr = unsafe { base.add(4096 - 2 - 8) };
	// ...
}
```

base\_ptr is of type \*mut MaybeUninit<Chunk<T>>, so I was skipping a few thousand whole chunks,
landing very deep in uninitialized memory.

```rust
	// fixed:
        let store_ptr = store.as_mut_ptr() as *mut MaybeUninit<u8>;
```

This is also a bit of a lesson about the scope of unsafe: while the unsafe block itself might be short
everything that touches things that are also relied on in an unsafe context is also very relevant.
In fact The whole module should probably be considered unsafe, because private values are accessible.
For example changing the Chunks length field would lead to undefined behaviour, even though its a "safe" operation.

### Lengths

Now that I had the ability to create a new Chunk,
I wanted to actually do something with it.
Like for example inserting and removing elements.

An insert is a memcopy, followed by a write,
a remove is a swap followed by a memcopy.

the swap/write are quite straightforward,
but I made some mistakes with the memcopy:

```rust
fn insert(&mut self, index: usize, element: T) -> Option<T> {
	// ...

	let (_pre, values, _post) = unsafe { self.buf.align_to() };
	let copy_source_index = &mut values[index] as *mut MaybeUninit<T>;
	// pointers are allowed to overshoot an allocation by one,
	// so this is fine.
	let copy_target = unsafe { copy_source.add(1) };

    	let remainder = self.len - index;
	
	unsafe { std::ptr::copy(copy_source, copy_target, len) };
	// ...
}
```
This is an acceptable implementation of insert (with important sanity checks removed for brevity).
Now lets do remove! Basically the same as insert, but with source and target swapped.

```rust
fn remove(&mut self, index: usize) -> Option<T> {
	// ...
	let (_pre, values, _post) = unsafe { self.buf.align_to() };
	let copy_target = &mut values[index] as *mut MaybeUninit<T>;
	let copy_source = unsafe { copy_target.add(1) };

	let remainder = self.len - index;

	unsafe { std::ptr::copy(copy_source, copy_target, remainder) };
	// ...
}
```

Except that's wrong.

```rust
	let remainder = self.len - (index + 1);
```
is correct because the value at index has just been removed, that was the whole point!

Found this one with miri.

## Dealing with unsafe
Seeing all the mistakes I made here is some rules I use to try and avoid them:

### Avoid
Do not use unsafe, if you can somehow avoid it.
If you need something chances are someone else already did it,
just use their code!
You can even help them review it to catch issues.

I have seen people use unsafe for performance reasons,
especially to avoid zeroing something
but it seems to almost never actually make a difference.

### Read & Think
Read and think about the rules around [pointers](https://doc.rust-lang.org/std/ptr/index.html) and [uninitialized data](https://doc.rust-lang.org/std/mem/union.MaybeUninit.html) in rust.
Also there is the [Nomicon](https://doc.rust-lang.org/nomicon/index.html).

### Code Carefully
I put each unsafe operation into its own block.
Each block gets a comment on why I personally think this operation is sound.

### Tests
Write tests for all the unsafe code you create.
Make sure to cover edge-cases,
in my example that would be inserting/removing at the last position.

### Miri
Use miri! Its really useful and easy to get started with.
```bash
$ rustup component add miri
$ cargo miri test
```

miri can't test code it does not see,
so make sure your tests actually run the important parts.

Also it won't catch every problem in the code it does see, not a replacement for thinking!

## Conclusion
Hope you learned something from this post,
maybe about unsafe,
maybe about never trusting code I write cause its got an error every 20 lines.
Or maybe you feel inspired to review the unsafe parts of your favourite library!

