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
ZP_SYNC_RASTER = $b0                    ; used to sync raster
ZP_BIT_IDX_TOP = $b1                    ; bit to be displayed
ZP_BIT_IDX_BOTTOM = $b2


.segment "CODE"
        sei

        jsr generator

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
        sta ZP_BIT_IDX_BOTTOM

        lda #1
        sta ZP_BIT_IDX_TOP

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
        stx ZP_BIT_IDX_TOP
        ldx #0
        stx ZP_BIT_IDX_BOTTOM
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


        jsr $c000                       ; do the rolling (upper part)
                                        ; code is autogenrated in runtime


        ; fetch bottom part of the char
        ; and repeat the same thing
        ; which is 1024 chars appart from the previous.
        ; so, I only have to add #4 to $fd
        clc
        lda $fd
        adc #04                         ; the same thing as adding 1024
        sta $fd

        lda ZP_BIT_IDX_BOTTOM           ; if bit_idx_bottom == 0, then char + 1
        cmp #$07
        bne l0
        inc $fc
        bne l0
        inc $fd

l0:
        ldy $fb                         ; restore Y from tmp variable


        jsr $c400                       ; do the rolling (bottom part)
                                        ; code is autogenrated in runtime

        ldx ZP_BIT_IDX_TOP              ; bit idx top
        inx
        cpx #8
        bne l1

        ldx #0
        clc
        inc load_scroll_addr
        bne l1
        inc load_scroll_addr+1
l1:
        stx ZP_BIT_IDX_TOP


        dex                             ; bit_idx_bottom = bit_idx_top - 1
        cpx #$ff
        bne l2

        ldx #7
l2:
        stx ZP_BIT_IDX_BOTTOM

        rts

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
        scrcode "       "
        scrcode "hi everyone at silesia from pvm argentina. this world is held together "
        scrcode "by the few acts of kindness that random ppl do so this little. intro is "
        scrcode "our way to leave something other than unpaid debts after we die. 4k is a "
        scrcode "bitch but our team of coders: acidbrain, munshkr, riq & woz made it work in a "
        scrcode "joint effort. the logo was done by sc0ring and alakran adapted it to c64. "
        scrcode "arlequin made the font and uctumi created this eardrum-piercing sid that "
        scrcode "will loop inside your brain probably forever. have a great party!"
        scrcode "       "
        .byte $ff

.proc generator
        ldx #0
        lda #$2e                        ; set everything with 'rol'
l0:
        sta $c000,x
        sta $c100,x
        sta $c200,x
        sta $c300,x
        sta $c400,x
        sta $c500,x
        sta $c600,x
        sta $c700,x
        sta $c800,x
        dex
        bne l0

        ldx #<($c000)                   ; where to generate the code
        ldy #>($c000)
        stx $92
        sty $93

        ldy #0
        sty $81                         ; index to table_rel

        jsr generate_loop

        ldx #<($c400)                   ; where to generate the code
        ldy #>($c400)
        stx $92
        sty $93

        ldy #8
        sty $81                         ; index to table_rel

        jmp generate_loop
.endproc

.proc generate_loop

        lda #8                          ; repeat 8 times
        sta $80

l1_1:
        jsr generate_jsr                ; jsr loop_jump

        ldy $81
        ldx #0
l1:

        clc
        lda table_base_lo,x             ; base always uses x
        adc table_rel_lo,y              ; rel always uses y since y will vary in each iteration
        sta $90
        lda table_base_hi,x
        adc table_rel_hi,y
        sta $91

        jsr generate_rol_addr

        iny
        inx
        cpx #40
        bne l1

        jsr generate_iny

        inc $81                         ; Y counter. gets incremented once per loop. offset to rel. addresses
        dec $80                         ; repeat 8 times (once per bit)
        bne l1_1

        jmp generate_rts
.endproc

.proc generate_jsr
        lda #$20                        ; 'jsr' opcode
        ldy #0
        sta ($92),y

        lda #<loop_jump
        iny
        sta ($92),y

        lda #>loop_jump
        iny
        sta ($92),y

        jsr ptr_plus_3
        jmp ptr_plus_1
.endproc

.proc generate_iny
        jsr ptr_minus_1
        lda #$c8                       ; 'iny' opcode
        ldy #0
        sta ($92),y
        jmp ptr_plus_1
.endproc

.proc generate_rts
        jsr ptr_minus_1
        lda #$60                        ; 'rts' opcode
        ldy #0
        sta ($92),y
        jmp ptr_plus_1
.endproc


.proc generate_rol_addr
        tya
        pha

        ldy #$0
        lda $90                        ; lo addr to save
        sta ($92),y
        iny
        lda $91                        ; hi addr to save
        sta ($92),y

        jsr ptr_plus_3
        pla
        tay
        rts
.endproc

.proc ptr_plus_3
        clc
        lda $92
        adc #$03
        sta $92
        lda $93
        adc #$00
        sta $93
        rts
.endproc

.proc ptr_plus_1
        clc
        inc $92
        bcc end
        inc $93
end:
        rts
.endproc

.proc ptr_minus_1
        sec
        dec $92
        bcs end
        dec $93
end:
        rts
.endproc

.proc loop_jump
        lda ($fc),y
        ldx ZP_BIT_IDX_BOTTOM      ; set C according to the current bit index
:       asl
        dex
        bpl :-
        rts
.endproc


PIXEL_BASE = $6f00

table_base_lo:
        .repeat 40, XX
                .byte <(PIXEL_BASE + $0138 - 8 * XX)
        .endrepeat
table_base_hi:
        .repeat 40, XX
                .byte >(PIXEL_BASE + $0138 - 8 * XX)
        .endrepeat

table_rel_lo:
        .repeat 7, YY
                .repeat 8, XX
                        .byte <(XX + $0140 * YY)
                .endrepeat
        .endrepeat

table_rel_hi:
        .repeat 7, YY
                .repeat 8, XX
                        .byte >(XX + $0140 * YY)
                .endrepeat
        .endrepeat

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
