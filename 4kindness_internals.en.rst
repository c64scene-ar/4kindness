C64 Assembler Tutorial - Part II: Making a 4k Intro (intermediate)
=================================================================

:Version: 0.1.0 (`go to the latest version <https://github.com/c64scene-ar/4kindness/blob/master/4kindness_internals.en.rst>`__)
:Author: `riq <http://retro.moe>`__ / `Pungas of Villa Martelli <http://pungas.space>`__

.. contents:: Contents
   :depth: 2

Introduction
============

Hi. This is how the 4Kindness intro looks like:

.. Figure:: https://lh3.googleusercontent.com/y3C0o2PzEErAfDILRZSLyG9wV9HNSk58Udk-k--r6T80yqFkpny995jARy_4mFHKoiXjs8I2nfJhXbv3XNvRxjzWt-IYfZjQBVIn_t8KCNuHT4oVMQLnn-OJtLQSDiDk-jrs2OADaMs
   :alt: Intro 4Kindness

The binary can be downloaded from here: `4kindness.d64 <https://github.com/c64scene-ar/4kindness/raw/master/bin/4kindness.d64>`__.
And the source code is here: `4Kindness github <https://github.com/c64scene-ar/4kindness>`__

Let's start. We are going to cover only two topics:

- How to do a diagonal scroll
- How to generate code in runtime


Diagonal scroll
===============

In Part_I_ we saw how to do a scroll with sprites. In case you don't know how or
don't remember how to do it, here is the info: `Scroll with sprites <https://github.com/c64scene-ar/chipdisk-nac-vol.1/blob/master/chipdisk_internals.en.rst#scroll-with-sprites>`__

Scrolling with hi-res sprites, or with hi-res graphic mode is more or less the
same. Let's review the hi-res graphic mode.

- It consists of 40 x 25 cells:

.. Figure:: https://lh3.googleusercontent.com/K_YyuNocoS4yaVxr2uuJgraYpI5An3BwgxahScn3bDjdFBsLj4b6h-g4ngUxkbOfXqlkpSQuQIKeGGEgVgrsShnI5FnIl8GSKw8msFEYmGatIrfTKp_5RpFPTsmgZYZ1N-2fH3T1QMc
   :alt: bitmap cells

- Each cell takes 8 bytes:

.. Figure:: https://lh3.googleusercontent.com/lqU7dLG2RpCfhoZ-pw2L3zNjkLVOgsjAdHxM5JtYnLy7gwO7K7i-lxRawKgyKhloBcvO3IzZ1vl36sthotpo7DSFIhdj7X9-qbnbh5Bp8OjjwajeKwcwOouhZgqqDKL4amN1TwRczac
   :alt: cell detail


In total it takes 40 cells * 8 bytes each * 25 cells = 8000 bytes. Color memory
takes another 1000 bytes (but we are not interested in that for the scroll).

If we want to do a horizontal scroll in hi-res graphic mode, we only have to
``rol`` (*rotate left*) the bytes in a certain order. The *carry flag* must be
propagated from one byte to another.

.. Figure:: https://lh3.googleusercontent.com/oEBuQcNd5kJmrhFS9MVPtRaaRMS6Mbe_TqzaAmzlz8q7fPY-_GsicScFhf5gtop6_3ifH0kG-4EIpJtUmvdIJnK0wlURmVk1wMCqhR_FPzY47z2BlOZZsBzPBK41c_CKzXPtRZywA9c
   :alt: horizontal scroll

Suppose we want to scroll the first row of cells (each row takes 8 bytes), then
a possible solution would be:

.. code:: asm

        ; variables
        BITMAP_ADDR = $6000     ; bitmap start address
        cell_x0_0  = BITMAP_ADDR +  0 * 8 + 0
        cell_x0_1  = BITMAP_ADDR +  0 * 8 + 1
        ...
        cell_x39_6 = BITMAP_ADDR + 39 * 8 + 6
        cell_x39_7 = BITMAP_ADDR + 39 * 8 + 7
        ...

        ; rotate-left row 0
        jsr get_carry_value
        rol cell_x39_0
        rol cell_x38_0
        ...
        rol cell_x1_0
        rol cell_x0_0

        ; rotate-left row 1
        jsr get_carry_value
        rol cell_x39_1
        rol cell_x38_1
        ...
        rol cell_x1_1
        rol cell_x0_1

        ; rotate-left row 7
        jsr get_carry_value
        rol cell_x39_7
        rol cell_x38_7
        ...
        rol cell_x1_7
        rol cell_x0_7


The code can be reduced by using an *unrolled loop* with the powerful
macros (see Part I: `Unrolled loops <https://github.com/c64scene-ar/chipdisk-nac-vol.1/blob/master/chipdisk_internals.en.rst#trick-unrolled-loops>`__
). Using macros, the code should look like the following:

.. code:: asm

        ; scroll top 8 bits
        ; FF = offset within the cell
        ; XX = bitmap cols (cell x position)
        .repeat 8, FF
                jsr get_carry_value

                .repeat 40, XX
                        rol BITMAP_ADDR + (39 - XX) * 8 + FF
                .endrepeat
        .endrepeat


That's it!
Now that we know how to do a horizontal scroll using bitmap, let's do it
diagonally.

The idea is similar. The scroll we want to do has the following slope:

.. Figure:: https://lh3.googleusercontent.com/EBZt0OIIXfiSuHnllmPaAYNJeGQ0tm7U7b-lT1MX_JOgGzrpDODhGHHeHa4MS5ErBbeyQ8XFK9MxTRCR9kPNB7D8b-XuJJo4P_HMz3cdpX3uiVTykr2XNZ0spJhvZBqyVoRAmvWa7EE

In this case it helps to write "by hand" how the scroll should behave. To scroll
only the first row of bits, you have to do:


.. code:: asm

        ; variables
        BITMAP_ADDR = $6000
        ; formula:
        ;cell_yYY_xXX_FF  = BITMAP_ADDR + 320 * YY + 8 * XX + FF
        ;
        ; eg:
        ;cell_y2_x12_7 = BITMAP_ADDR + 320 * 2 + 8 * 12 + 7
        ;
        ; 320 = 40 * 8 (40 rows and each row contains 8 bytes)

        jsr get_carry_value

        rol cell_y0_x39_0
        rol cell_y0_x38_1
        ...
        rol cell_y0_x33_6
        rol cell_y0_x32_7

        ; go to the next cell row: Y = Y + 1

        rol cell_y1_x31_0
        rol cell_y1_x30_1
        ...
        rol cell_y1_x25_6
        rol cell_y1_x24_7

        ; go to the next cell row: Y = Y + 1

        rol cell_y2_x23_0
        rol cell_y2_x22_1
        ...
        rol cell_y2_x17_6
        rol cell_y2_x16_7

        ... an so on


And now we have to turn that into an algorithm. We have 3 variables.
Let's look at the patterns:

- ``y``: for every 8 ``rol``, it is incremented by 1
- ``x``: for each ``rol``, it is decremented by 1
- ``offset``: for each ``rol``, it is incremented by 1. With values between 0
  and 7. That is, module 8.

Pseudo code:

.. code:: c

        // scroll diagonally the first row of bits
        for (int i=0; i<40; i++) {
            y = i / 8;
            x = 39 - i;
            offset = i % 8;

            addr = BITMAP_ADDR + 320 * y + 8 * x + offset;
            rol(addr);
        }


And to work for the first 8 rows of bits, and extra loop is needed:

.. code:: c

        // scroll diagonally the first 8 rows of bits
        for (int j=0; j<8; j++) {
            for (int i=0; i<40; i++) {
                y = (i + j) / 8;
                x = 39 - i;
                offset = (i + j) % 8;

                addr = BITMAP_ADDR + 320 * y + 8 * x + offset;
                rol(addr);
            }
        }


Converted to assembler, the code looks like the following:

.. code:: asm

        ; scroll top 8 bits diagonally
        ; FF = offset within the cell
        ; XX = bitmap cols (cell x position)
        .repeat 8, FF
                jsr get_carry_value

                .repeat 40, XX
                        rol BITMAP_ADDR + (39 - XX) * 8 + (40*8) * ((XX+FF) / 8) + (XX+FF) .MOD 8
                .endrepeat
        .endrepeat


Done! I want to highlight how easy it is to write algorithms using **unrolled
loops + macros**. Convert that algorithm to assembler without macros or
*unrolled loops* (left as an excersice for the reader). You'll see that it can
get complex.

**Let me say it again**: Algorithms that are easy to write in C, but difficult
to write in *pure* assembler, can be converted relatively simple to assembler
with *unrolled loops* + macros.

Not only is it easier to do, but also generates much faster code! In addition,
the code is more maintainable.

What's the catch? You pay a high price on using *unrolled loops*: RAM. A simple
loop that may take tens of bytes, when it is converted to *unrolled loop*
can take a few thousand bytes.

In Part_I_ we used *unrolled loops* to improve performance. In this case we use
*unrolled loops* to simplify the code. Faster code is also a nice feature, but
in this case is secongary goal.

It is a compromise: memory RAM or faster code & more verbose code

    .. note:: The algorithm can be written in C. In fact we use cc65_ as the
      assembler. And mixing C with assembler can be very useful. But it is
      outside the scope of tutorial to learn how to do it C.


Code Generator
==============

We presented this scroller, 4Kindness, in a 4k Intro contest. This means that
the binary can not take more than 4096 bytes. But in memory it can take as much
as it wants. In fact 4Kindness takes about 16K RAM:

- bitmap graphic: 9k
- music SID: 2.5k
- fonts: 1k
- code: 2.5k (of which 2k belongs to the *unrolled loop*)

The compressed binary [#]_ was about ~5k.

We were able to reduce the size by simplifying the music, the fonts, and by
using the Zero Page. After that the file size was about ~4.5k. In order to reach
to the 4k goal, we knew we had to reduce the size of the *unrolled loop*:

We considered 4 possible alternatives:

- Do the loop in C
- Do the loop in assembler
- Make a code generator in C
- Make a code generator in assembler

We ended up using the code generator in assembler. But the other 3 alternatives
were valid. There is almost always more than one possible solution. It is a
matter of analyzing its pros and cons.


Why a Code Generator
--------------------

The question is: can you make a code generator that takes less size than the
one generated by crunchers_ (like the alz64_ or the Exomizer_)?

If what we want is to compress an *unrolled loops*, the answer is almost always
yes. The reason is twofold:

- An unrolled loop is a pattern that repeats itself with only a few bytes
  changing in each iteration.
- While the c64 crunchers work well, remember that the *de-cruncher* code has
  to run on the c64, take very little memory, and be fast. That's why we don't
  use modern compressors such as bzip2_ or the xz_.


How to make a code generator
----------------------------

There is no black magic or anything strange. What you have to do is analyze the
bytes that one wants to generate, look for patterns and make a code that
generates those patterns. Whenever we want to generate code from an *unrolled
loop*, we will be able to find a pattern.

For example, this is a memory dump of what we want to generate:

.. Figure:: https://lh3.googleusercontent.com/eGInnhLFkmqw4SbOp54_kXuN-JVQetVtZ-kwSPEg2rHH7xZvyeYq1_Mm6AINS3xUiHLBkh1_SBo4B3BklbtP_zsfoNmLkFMZWYGy0G2Wez7uBGJzuHQXoUS6pcSwgWASrh-ENn3CzA8
   :alt: memory dump


Let's analyze the first 3 bytes: ``2E 38 70``

- ``2E`` is the opcode for ``rol``
- ``38 70`` is the memory address in *little endian*: ``$7038``

Let's analyze the first 40 ``rols``:

.. code:: asm

        ; scrolling row 0
        rol $7038       ; cell x=39  y=0
        rol $7031       ; cell x=38  y=0
        rol $702a       ; cell x=37  y=0
        rol $7023       ; cell x=36  y=0
        rol $701c       ; cell x=35  y=0
        rol $7015       ; cell x=34  y=0
        rol $700e       ; cell x=33  y=0
        rol $7007       ; cell x=32  y=0


        rol $7138       ; cell x=31  y=1
        rol $7131       ; cell x=30  y=1
        ...
        rol $710e       ; cell x=25  y=1
        rol $7107       ; cell x=24  y=1


        rol $7238       ; cell x=23  y=2
        rol $7231       ; cell x=22  y=2
        ...
        rol $720e       ; cell x=17  y=2
        rol $7207       ; cell x=16  y=2

        ...


There is a clear pattern:

- The values of the first 8 ``rol`` are separated by ``-7``: ``$7038``,
  ``$7031``, ...
- The following 8 ``rol`` are the same as the previous 8, but their values are
  ``$100`` more. ``$100`` is a nice number, we like it!

The bytes that we are seeing are consistent with our algorithm.

Let's see what happens with the following 40 ``rol``:

.. code:: asm

        ; scrolling row 1
        rol $7039       ; cell x=39  y=0
        rol $7032       ; cell x=38  y=0
        rol $702b       ; cell x=37  y=0
        rol $7024       ; cell x=36  y=0
        rol $701d       ; cell x=35  y=0
        rol $7016       ; cell x=34  y=0
        rol $700f       ; cell x=33  y=0
        rol $7140       ; cell x=32  y=1


        rol $7139       ; cell x=39  y=1
        rol $7132       ; cell x=38  y=1
        ...
        rol $710f       ; cell x=33  y=1
        rol $7240       ; cell x=32  y=2


        rol $7239       ; cell x=39  y=2
        rol $7232       ; cell x=38  y=2
        ...
        rol $720f       ; cell x=33  y=2
        rol $7340       ; cell x=32  y=3


Similar to the previous case, but with one important difference:

- The values of the first 7 ``rol`` are separated by ``-7``: ``$7039``,
  ``$7032``, ...
- The value of the following ``rol`` is separated by ``305`` (305 = 320 - 7 - 8)
- The following 8 ``rol`` are the same as the previous 8, but their values are
  ``$100`` bigger (as with the first 40 ``rol``)

And if we analyze see the next 40 ``rol``:

.. code:: asm

        ; scrolling row 2
        rol $703a       ; cell x=39  y=0
        rol $7033       ; cell x=38  y=0
        rol $702c       ; cell x=37  y=0
        rol $7025       ; cell x=36  y=0
        rol $701e       ; cell x=35  y=0
        rol $7017       ; cell x=34  y=0
        rol $7148       ; cell x=33  y=1
        rol $7141       ; cell x=32  y=1


        rol $7139       ; cell x=39  y=1
        rol $7132       ; cell x=38  y=1
        ...
        rol $7248       ; cell x=33  y=2
        rol $7241       ; cell x=32  y=2


        rol $723a       ; cell x=39  y=2
        rol $7233       ; cell x=38  y=2
        ...
        rol $7348       ; cell x=33  y=3
        rol $7341       ; cell x=32  y=3

        ...

Similar to the previous 40 ``rol``.

- The values of the first 6 ``rol`` are separated by ``-7``: ``$703a``,
  ``$7033``, ...
- The value of the following ``rol`` is separated by ``305`` (305 = 320 - 7 - 8)
- The value of the following ``rol`` is separated by ``-7``
- The following 8 ``rol`` are the same as the previous 8, but their values are
  ``$100`` higher (as with the first 40 ``rol``)

So, do you see the pattern? There are probably several ways to generate code
that we want. We ended up using tables with a *base* + *offset*. It works like
this:

.. code:: c

        // pseudo code

        // all values are in hexadecimal
        int base_gfx = $6f00;        // top-left = $6f00. top-right=$7138

        // 40 values
        int base[] = {$138,$130,$128,$120,$118,$110,$108,$100,     // 40 values from:
                     $f8,$f0,$e8,$e0,$d8,$d0,$c8,$c0,              // 312 to 0
                     ...,                                          // with a step of 8
                     $38,$30,$28,$20,$18,$10,$8,$0};

        // 56 values
        int offset[] = {0,1,2,3,4,5,6,7,                           // 0-7
                        $140,$141,$142,$143,$144,$145,$146,$147,   // 320-327
                        $280,$281,$282,$283,$284,$285,$286,$287,   // 640-647
                        $3c0,$3c1,$3c2,$3c3,$3c4,$3c5,$3c6,$3c7,   // 960-967
                        ...
                       };

        int y = 0;
        int x = 0;

        for (int i=0; i<8; i++) {
            y=i;                                // y increments by 1 each iteration
            for (x=0; x<40; x++) {
                int rol_value = base_gfx;
                rol_value += base[x];
                rol_value += offset[y];
                generate_addr(rol_value);

                y++;
            }
        }

Let's test the pseudo-code for the first row (*row 0*):

.. code::

        //        gfx   + base + offset =
        value 0 = $6f00 + $138 +    0 = $7038 ✔
        value 1 = $6f00 + $130 +    1 = $7031 ✔
        ...
        value 6 = $6f00 + $108 +    6 = $700e ✔
        value 7 = $6f00 + $100 +    7 = $7007 ✔

        value 8 = $6f00 +  $f8 + $140 = $7138 ✔

It seems to work ... let's test it for second row (*row 1*):

.. code::

        //         gfx   + base + offset =
        value 40 = $6f00 + $138 +    1 = $7039 ✔
        value 41 = $6f00 + $130 +    2 = $7032 ✔
        ...
        value 46 = $6f00 + $108 +    7 = $700f ✔
        value 47 = $6f00 + $100 + $140 = $7140 ✔

        value 48 = $6f00 +  $f8 + $141 = $7139 ✔

It works. And it also works for the 3rd row, 4th, etc. We have a working
value-generator for ``rol``.

The complete assembler code is in `github <https://github.com/c64scene-ar/4kindness/blob/master/intro.s#L233>`__.
There is nothing strange except. But it is worth describing how we use the
tables in assembler:

.. code:: asm

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

So, how many bytes does the code-generator take?

Without compression:

- Using *unrolled loop*: ``2078 bytes``
- Using code generator: ``423 bytes``

Using the alz64_ cruncher:

- Using *unrolled loop*: ``730 bytes``
- Using code generator: ``260 bytes``

And thanks to those ``470 bytes`` (730-260) we were able to reach the 4k goal.


Conclusions
-----------

- It is not common to have to generate code
- In case you need it, identify the *unrolled loop* that takes more space, and
  create a code-generator for it.
- If the identified pattern requires comples math operations, replace them with
  tables.


Questions and others
====================

Do you have questions? Do you want to collaborate with PVM? We're here:

-  http://pungas.space
-  On IRC. `EFnet <http://www.efnet.org/>`__ . Channel #pvm
-  `Twitter <https://twitter.com/pungas64>`__
-  `Facebook <https://www.facebook.com/PVM1996/>`__


References
==========

.. [#] We use `alz64 <http://csdb.dk/release/?id=77754>`__ as the cruncher, since it compresses better than Exomizer_, but it is slower

.. _Exomizer: https://bitbucket.org/magli143/exomizer/wiki/Home
.. _Part_I: https://github.com/c64scene-ar/chipdisk-nac-vol.1/blob/master/chipdisk_internals.en.rst
.. _alz64: http://csdb.dk/release/?id=77754
.. _bounding-box: https://en.wikipedia.org/wiki/Minimum_bounding_box
.. _bzip2: http://www.bzip.org/
.. _cc65: https://github.com/cc65/cc65
.. _crunchers: http://iancoog.altervista.org/PACKERS.TXT
.. _xz: https://en.wikipedia.org/wiki/Xz
