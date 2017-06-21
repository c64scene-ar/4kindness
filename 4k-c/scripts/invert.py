#data = open("font_caren_1x2-charset.bin", "rb").read()
data = open("arleka_font_caren_remix0A-charset.bin", "rb").read()
x = ""
for d in data:
    x += chr(0xff - ord(d))
#fh = open("inverted.bin", "wb")
fh = open("arleka_font_caren_remix0A_invert-charset.bin", "wb")
fh.write(x)
fh.close()


