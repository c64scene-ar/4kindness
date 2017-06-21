
print "Inclinado **********"
BITMAP_ADDR = 0x6000+ 8 * 40 * 12
for YY in range(8):
    print "-"
    last_value = 0
    for SS in range(40):
        addr_base = BITMAP_ADDR + (39 - SS) * 8
        addr_rel = (40*8) * ((SS+YY) / 8) + (SS+YY) % 8
        addr_total = addr_base + addr_rel
        print "addr base: $%04x + addr rel: $%04x = $%04x (diff=$%04x)" % (addr_base, addr_rel, addr_total, addr_total - last_value)
        last_value = addr_total

#print "Normal *********"
#BITMAP_ADDR = 0
#for YY in range(8):
#    print "-"
#    for SS in range(40):
#        addr_base = BITMAP_ADDR + (39 - SS) * 8
#        addr_rel = YY
#        addr_total = addr_base + addr_rel
#        print "addr base: $%04x - addr rel: $%04x = $%04x" % (addr_base, addr_rel, addr_total)
