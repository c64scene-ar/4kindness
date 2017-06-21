import os
import sys

if len(sys.argv) != 3:
    print "Usage:", sys.argv[0], "binfile outfile.h"

b_fname = sys.argv[1]
out_fname = sys.argv[2]

data = open(b_fname, "rb").read()[2:]
h_data = "unsigned char " + os.path.basename(out_fname).lower().split(".")[0] + "[] = "
h_len = len(h_data)

for i in range(0, len(data), 40):
    bin_data = data[i:i+40]
    if i != 0:
        h_data += " " * h_len
    h_data += "\"\\x" 
    h_data += "\\x".join(hex(ord(x))[2:].zfill(2) for x in bin_data) + "\"\\\n"

o_data = h_data[:-2] + ";\n"
fh = open(out_fname, "w")
fh.write(o_data)
fh.close()



