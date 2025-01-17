+++
title = "Introduction to my Blog"
date = 2020-01-07
[taxonomies]
tags = ["rust", "web"]
categories = ["blog"]
+++

This blog will mainly contain release announcements for my various projects, some deep dives into designs or optimizations I did. Also some opinions sometimes.

<!-- more -->

It seems like a hard requirement for being a rust developer is to have a blog and a twitter, I don't like twitter so here is my blog :D.

It will probably be nice to have some place to write down long-form thoughts and share them with others.
When writing about tech I want the posts to be a mini-tutorial, too, so to get started:

I built this site using zola, the "after-dark" theme and github pages. Just straightforward following the tutorials, no real customization.
The [git repository](https://github.com/djugei/djugei.github.io) has two branches, the "raw" branch contains the zola configuration and markdown content, while the "master" branch contains the rendered page, ready to serve. I have both repositories checked out locally in twin Folders. The deploy.sh script builds and copies the rendered pages to the master branch.

i made some slight adjustments to the theme, namely adding rss links everywhere. Sadly i had to copy a lot of the themes templates to do that, not sure if there is a better way (besides forking the template).

I have also imported all my reddit posts to get started.
