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
.export _animate_scroll
;.import _testit

DEBUG = 0                               ; rasterlines:1, music:2, all:3

;BITMAP_ADDR = $6000 + 8 * 40 * 12

.segment "CODE"

;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
; animate_scroll
;=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-;
.proc _animate_scroll

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

                ; jump to generated code
                jsr $a000 + YY * 121

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

                ; jump to generated code
                jsr $a3d0 + YY * 121
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

; starts with an empty (white) palette

scroll_text:
        scrcode " lorem ipsum dolor sit amet, consectetur adipiscing elit. suspendisse ligula lorem, varius a quam eu, semper faucibus orci. donec sed auctor risus. praesent non nisi non odio aliquet posuere suscipit e"
        .byte 96,97
        .byte 96,97
        .byte 96,97
        scrcode "  "
        .byte $ff


; charset to be used for sprites here
charset:
        ;.incbin "inverted.bin"
        ;.incbin "../res/arleka_font_caren_remix0A-charset.bin"
        .incbin "../res/font-opt-invert.bin"
;        .incbin "../res/arleka_font_caren_remix0A_invert-charset.bin"
;        .incbin "font_caren_1x2-charset.bin"


