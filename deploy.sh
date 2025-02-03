#!/bin/bash
zola build
rsync -vr --exclude=".*" public/ ../
