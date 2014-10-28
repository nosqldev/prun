#!/bin/sh
# 2014-10-28 22:01

time ./simple.pl > p.txt
md5sum *txt
rm -f p.txt
