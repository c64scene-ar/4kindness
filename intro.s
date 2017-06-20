;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; Scroller using bitmap
;
; Original code by Riq
; https://github.com/ricardoquesada/c64-misc
; 
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;


;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; Macros
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.macpack cbm                            ; adds support for scrcode

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; Constants
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
;.include "c64.inc"                      ; c64 constants

DEBUG = 0                               ; rasterlines:1, music:2, all:3

BITMAP_ADDR = $6000 + 8 * 40 * 12

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; ZP variables
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
ZP_SYNC_RASTER = $fe                    ; used to sync raster


.segment "CODE"
        sei

        lda #$35                        ; no basic, no kernal
        sta $01

        jsr $8000 ; init music

        ; select bank 1 ($4000-$7fff)
        lda $dd00
        and #%11111100
        ora #%00000010
        sta $dd00

        lda #2
        sta $d020                       ; border color

        lda #0
        sta $d021                       ; background color
        sta ZP_SYNC_RASTER

        lda #%00001000                  ; no scroll, hires (mono color), 40-cols
        sta $d016
        
        lda #%00111011                  ; bitmap mode, default scroll-Y position, 25-rows
        sta $d011

        lda #%00001100                  ; bitmap addr: $2000 (6000), charset $1800 (not-used), video RAM: $0000 ($4000)
        sta $d018

        lda #$7f                        ; turn off cia interrups
        sta $dc0d
        sta $dd0d

        lda #01                         ; enable raster irq
        sta $d01a
      
        lda #$50
        sta $d012

        ldx #<irq                       ; setup IRQ vector
        ldy #>irq
        stx $fffe
        sty $ffff
  
        lda $dc0d                       ; ack possible interrupts
        lda $dd0d
        asl $d019

        cli

main_loop:
        lda ZP_SYNC_RASTER
        beq main_loop

.if (::DEBUG & 1)
        inc $d020
.endif
        jsr $8003 ; play music
        dec ZP_SYNC_RASTER
        jsr animate_scroll
.if (::DEBUG & 1)
        dec $d020
.endif
        jmp main_loop

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; animate_scroll
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc animate_scroll

        ; zero page variables f0-f9 are being used by the sid player (I guess)
        ; use fa-ff then
        lda #0
        sta $fa                         ; tmp variable

        ldx #<charset
        ldy #>charset
        stx $fc
        sty $fd                         ; pointer to charset

load_scroll_addr = * + 1
        lda scroll_text                 ; self-modifying
        cmp #$ff
        bne next
        ldx #1
        stx bit_idx_top
        ldx #0
        stx bit_idx_bottom
        ldx #<scroll_text
        ldy #>scroll_text
        stx load_scroll_addr
        sty load_scroll_addr+1
        lda scroll_text

next:
        clc                             ; char_idx * 8
        asl
        rol $fa
        asl
        rol $fa
        asl
        rol $fa

        tay                             ; char_def = ($fc),y
        sty $fb                         ; to be used in the bottom part of the char

        clc
        lda $fd
        adc $fa                         ; A = charset[char_idx * 8]
        sta $fd


        ; scroll top 8 bytes
        ; YY = char rows
        ; SS = bitmap cols
        .repeat 8, YY
                lda ($fc),y
                ldx bit_idx_top         ; set C according to the current bit index
:               asl
                dex
                bpl :-

                .repeat 40, SS
                        rol BITMAP_ADDR + (39 - SS) * 8 + (40*8) * ((SS+YY) / 8) + (SS+YY) .MOD 8
                .endrepeat
                iny                     ; byte of the char
        .endrepeat


        ; fetch bottom part of the char
        ; and repeat the same thing
        ; which is 1024 chars appart from the previous.
        ; so, I only have to add #4 to $fd
        clc
        lda $fd
        adc #04                         ; the same thing as adding 1024
        sta $fd

        lda bit_idx_bottom              ; if bit_idx_bottom == 0, then char + 1
        cmp #$07
        bne :+
        cld
        lda $fc
        adc #$01
        sta $fc
        lda $fd
        adc #$00
        sta $fd

:
        ldy $fb                         ; restore Y from tmp variable

        ; scroll middle 8 bytes
        ; YY = char rows
        ; SS = bitmap cols
        .repeat 8, YY
                lda ($fc),y
                ldx bit_idx_bottom      ; set C according to the current bit index
:               asl
                dex
                bpl :-

                .repeat 40, SS
                        rol BITMAP_ADDR + 40 * 8 + (39 - SS) * 8 + (40*8) * ((SS+YY) / 8) + (SS+YY) .MOD 8
                .endrepeat
                iny                     ; byte of the char
        .endrepeat


        ldx bit_idx_top                 ; bit idx top
        inx
        cpx #8
        bne l1

        ldx #0
        clc
        lda load_scroll_addr
        adc #1
        sta load_scroll_addr
        bcc l1
        inc load_scroll_addr+1
l1:
        stx bit_idx_top


        dex                             ; bit_idx_bottom = bit_idx_top - 1
        cpx #$ff
        bne l2

        ldx #7
l2:
        stx bit_idx_bottom

        rts

bit_idx_top:
        .byte 1                         ; points to the bit displayed
bit_idx_bottom:
        .byte 0                         ; points to the bit displayed
.endproc


;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; irq vector
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc irq
        pha                             ; saves A

        asl $d019                       ; clears raster interrupt
        inc ZP_SYNC_RASTER

        pla                             ; restores A
        rti                             ; restores previous PC, status
.endproc


; starts with an empty (white) palette

scroll_text:
        scrcode " Probando scroll en diagonal en bitmap... la pendiente de la diagonal es 8x1."
        scrcode " Otro tipo de pendiente puede llevar mucho mas poder de computo ya que no podria usar 'rol' y tendria que usar algo mas especifico...    "
        .byte 96,97
        .byte 96,97
        .byte 96,97
        scrcode "  "
        .byte $ff


; charset to be used for sprites here
charset:
;        .incbin "res/arleka_font_caren_remix0A-charset.bin" 
        .incbin "res/arleka_font_caren_remix0A_invert-charset.bin"

.segment "BMP_VS"
        .incbin "res/logo-v.c64",2
;.incbin "res/puas3-v.c64",2

.segment "BMP_BS"
        .incbin "res/logo-b.c64",2
;        .incbin "res/puas3-b.c64",2

.segment "MUSIC_S"
        .incbin "res/music.c64",2
