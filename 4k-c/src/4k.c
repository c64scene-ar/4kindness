#include "pvmtypes.h"

#define sid_init() __asm__("lda #0"); __asm__("jsr $8000");
#define sid_play() __asm__("jsr $8003");

extern void animate_scroll(void);
extern unsigned char gfxb[];
extern unsigned char gfxv[];
extern unsigned char music[];

byte irq_executed;
unsigned short BITMAP_ADDR = 0x6000 + 8 * 40 * 12;
unsigned short base_addr;
unsigned short addr;
unsigned char YY;
unsigned char SS;
unsigned char *code;
byte i;

void do_copy(byte *dst, byte *src, unsigned short n) {
    unsigned short i;
    for (i = 0 ; i < n ; i ++) {
        *(dst+i) = *(src+i);
    }
}


void gen_code() {    
    code = (unsigned char *)0xa000;
    base_addr = BITMAP_ADDR;

    for (i = 0 ; i < 2 ; i ++) {
        for (YY = 0 ; YY < 8 ; YY ++) {
            for (SS = 0 ; SS < 40 ; SS ++) {
                addr = base_addr + (39 - SS) * 8 + (320) * ((SS+YY) / 8) + (SS+YY) % 8;
                *code = (byte)0x2e; // rol
                *(code+1) = (byte)(addr & 0xff);
                *(code+2) = (byte)(addr >> 8);
                code += 3;
            }
            *code = (byte)0x60; // rts
            code ++;
        }
        code = (unsigned char *)0xa3d0;
        base_addr += (40 * 8);
    }

}
void interrupt(void) {
    sid_play();
    __asm__("dec $d019"); 
    irq_executed = 1;
    __asm__("jsr $ea31");
}

void irq_init() {
    word *p;
    //VIC.rasterline = 0;     // Rasterline to generate IRQ at.
    // *((byte *)0xd012) = 0;

    //VIC.ctrl1 &= 0x7f;      // Rasterline bit #8 set to 0.
    //*((byte *)0xd011) &= 0x7f;

    __asm__("lda #$7f");    // Disable CIA IRQs.
    __asm__("sta $dc0d");

    p = (word *)0x314;
    *p = (word) &interrupt; // Set IRQ function

    __asm__ ("lda #$01");    // Enable Raster IRQs.
    __asm__ ("sta $d01a");
}

int main(void)
{
//    byte *screen_ram = 0x5c00;

    do_copy((void *)0x6000, gfxb, 8000);
   	do_copy((void *)0x5c00, gfxv, 1000);
   	do_copy((void *)0x8000, music, 2605);

    gen_code();
    sid_init();
    irq_init();

    *((byte *)0xd020) = 2;
    *((byte *)0xd021) = 0;

//    CIA2.pra = (CIA2.pra & 0xfc) | (3 - 1);
    *((byte *)0xdd00) = (*(byte *)0xdd00 & 0xfc) | 2;

//    VIC.addr = ((0x2000 >> 10) & 0x0e) | (0x1c00 >> 6); 
    *((byte *)0xd018) = ((0x2000 >> 10) & 0x0e) | (0x1c00 >> 6); 

//    VIC.ctrl2 &= 0xf7; // Screen Width = 40,   0xf7 = %11111111 - VIC Ctrl 2
//    *((byte *)0xd016) &= 0xff;

//    VIC.ctrl1 &= 0xf7; // Screen Height = 24,  0xf7 = %11110111 - VIC Ctrl 1
//    *((byte *)0xd011) &= 0xf7;

//    VIC.ctrl2 &= 0xef; // set multicolor mode = 0
//    *((byte *)0xd016) &= 0xef;

//    VIC.ctrl1 |= 0x20; // set bitmap mode = 1
    *((byte *)0xd011) |= 0x20;


    while(1) {
        // wait for vsync 
        while (!irq_executed) { }
        animate_scroll();
        irq_executed = 0;
    }
    return 0;
}
