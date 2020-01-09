#!/bin/bash
~/zola/target/release/zola build
rsync -vr --delete --exclude=".*" public/ ../djugei.github.io/
