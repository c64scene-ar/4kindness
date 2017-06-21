#!/usr/bin/env python
import sys

data = open(sys.argv[1], "rb").read()
x = ""
for d in data:
    x += chr(0xff - ord(d))
fh = open(sys.argv[2], "wb")
fh.write(x)
fh.close()
