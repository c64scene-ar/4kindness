Intermediate cms of asm for c64 - Part II: Making an intro 4k
====================================================================== =====================

: Version: 0.1.0 (`go to the latest version <https://github.com/c64scene-ar/puas/blob/master/4kindness_internals.es.rst>` __)
: Author: `riq <http://retro.moe>` __ / `Pungas of Villa Martelli <http://pungas.space>` __

.. contents :: Contents
   : Depth: 2

Introduction
============

Hi. Here's what the 4Kindness intro does:

.. Figure: https://lh3.googleusercontent.com/y3C0o2PzEErAfDILRZSLyG9wV9HNSk58Udk-k--r6T80yqFkpny995jARy_4mFHKoiXjs8I2nfJhXbv3XNvRxjzWt-IYfZjQBVIn_t8KCNuHT4oVMQLnn-OJtLQSDiDk-jrs2OADaMs
   : Alt: Intro 4Kindness

And the binary can be downloaded from here: `4kindness.d64 <https://github.com/c64scene-ar/4kindness/raw/master/bin/4kindness.d64>` __.
And the source code is here: `4Kindness en github <https://github.com/c64scene-ar/4kindness>` __

Okay, let's start. Only two things we are going to study:

- How to scroll diagonally
- How to generate code


Scroll diagonally
=================

In Part_I_ we saw how to do a scroll with sprites. It's a good time to reread it
in case you do not have it fresh: `How to do a scroll with sprites <https://github.com/c64scene-ar/chipdisk-nac-vol.1/blob/master/chipdisk_internals.en.rst>`__

Scrolling with hi-res sprites, or hi-res graphical mode is basically
the same. Let's review the hi-res graphic mode.

- It consists of 40 x 25 cells:

.. Figure:: https://lh3.googleusercontent.com/K_YyuNocoS4yaVxr2uuJgraYpI5An3BwgxahScn3bDjdFBsLj4b6h-g4ngUxkbOfXqlkpSQuQIKeGGEgVgrsShnI5FnIl8GSKw8msFEYmGatIrfTKp_5RpFPTsmgZYZ1N-2fH3T1QMc
   :alt: bitmap cells

- Each cell occupies 8 bytes:

.. Figure:: https://lh3.googleusercontent.com/lqU7dLG2RpCfhoZ-pw2L3zNjkLVOgsjAdHxM5JtYnLy7gwO7K7i-lxRawKgyKhloBcvO3IzZ1vl36sthotpo7DSFIhdj7X9-qbnbh5Bp8OjjwajeKwcwOouhZgqqDKL4amN1TwRczac
   :alt: cell detail


In total it occupies 40 cells * 8 bytes each * 25 cells = 8000 bytes. More memory
for color that are another 1000 bytes (but that we are not interested to make the
scroll).

If we want to do a horizontal scroll in hi-res graphical mode, we only have to
``rol`` (*rotate left *) of the bytes in a given order, since the
*carry flag* must be propagated from one byte to another.

.. Figure:: https://lh3.googleusercontent.com/oEBuQcNd5kJmrhFS9MVPtRaaRMS6Mbe_TqzaAmzlz8q7fPY-_GsicScFhf5gtop6_3ifH0kG-4EIpJtUmvdIJnK0wlURmVk1wMCqhR_FPzY47z2BlOZZsBzPBK41c_CKzXPtRZywA9c
   :alt: horizontal scroll

Suppose we want to scroll the first row of cells (the first 8 rows
Of bits from above), then a possible code would be:

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


The code can be greatly reduced by using an *unrolled loop* [#]_ with the
powerful assembler macros (see `Unrolled loops <https://github.com/c64scene-ar/chipdisk-nac-vol.1/blob/master/chipdisk_internals.es.rst#truquito-unrolled-loops>`__
Of Part I). It would look something like this:


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


And ready! Simple, right?
Now that we know how to do a horizontal scroll using bitmap, how do we that the
scroll is diagonal?

The idea is similar. The scroll we want to do has to have the following slope:

.. Figure:: https://lh3.googleusercontent.com/EBZt0OIIXfiSuHnllmPaAYNJeGQ0tm7U7b-lT1MX_JOgGzrpDODhGHHeHa4MS5ErBbeyQ8XFK9MxTRCR9kPNB7D8b-XuJJo4P_HMz3cdpX3uiVTykr2XNZ0spJhvZBqyVoRAmvWa7EE

In these cases it helps to write "by hand" as the scroll has to behave.
To scroll only the first row of bits, you have to do:


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

- ``and``: for every 8 ``rol``, it is incremented by 1
- ``x``: for each ``rol``, it is decremented by 1
- ``offset``: for each ``rol``, it is incremented by 1. With values between 0 and 7. That is, module 8.

In pseudo code would be:

.. code:: c

        // scroll en diagonal de la primer fila de bits
        for (int i=0; i<40; i++) {
            y = i / 8;
            x = 39 - i;
            offset = i % 8;

            addr = BITMAP_ADDR + 320 * y + 8 * x + offset;
            rol(addr);
        }


And to work for the first 8 rows of bits, one more loop is added:

.. code:: c

        // scroll en diagonal de las primeras 8 filas de bits
        for (int j=0; j<8; j++) {
            for (int i=0; i<40; i++) {
                y = (i + j) / 8;
                x = 39 - i;
                offset = (i + j) % 8;

                addr = BITMAP_ADDR + 320 * y + 8 * x + offset;
                rol(addr);
            }
        }


And now you have to pass it to assembler:

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


Ready! And I want to highlight how easy it is to write algorithms using **unrolled
loops + macros**. Exercise for the reader: convert that algorithm to
assembler without macros or *unrolled loops*. They'll see how fast they get
complicates

**Repeat**: Algorithms that are easy to write in C, but difficult to write
Write in assembler *pure*, can be converted relatively
Simple to assembler with *unrolled loops* + macros.

Not only is it easier to do, but the speed of execution
It's going to be much bigger! (And in addition the code is more maintainable).

But you pay a high price on using *unrolled loops*: RAM. A simple
loop that may occupy tens of bytes, when it is converted to *unrolled loop*
can occupy a few thousand bytes.

In Part_I_ we use *unrolled loops* to gain execution speed. In
this case we use *unrolled loops* to simplify the code (and in passing
Improve the speed of execution).

It is a compromise: RAM memory or execution speed & more verbose code

    .. note:: The algorithm can be written quietly in C. In fact
      We use cc65_ as an assembler. And mixing C with assembler can
      Be very useful. But it is outside the scope of the "asm circulation"
      The how to use C.


Code Generator
==============

4Kindness, this scroller we made, was to present it in a contest
Intros of 4k. This means that the binary can not occupy more than 4096 bytes.
But in memory you can occupy everything you want. In fact 4Kindness, in memory,
Occupy ~ 16K RAM:

- bitmap graphic: 9k
- music SID: 2.5k
- fonts: 1k
- code: 2.5k (of which 2k were of the *unrolled loop*)

When we compressed everything [#] _, we got a binary of ~ 5k.

We were able to reduce some of the music, the fonts and using the Zero Page we were in
The ~ 4.5k. Much more we could not reduce the binary without reducing those 2k of
Code generated by the *unrolled loop*.

We consider 4 possible alternatives:

- Do the loop in C
- Do the loop in assembler
- Make a code generator in C
- Make a code generator in assembler

We ended up using the code generator in assembler. But the other 3
Alternatives were valid. I tell this, because there is almost always more than
one possible solution. It is a matter of analyzing the pros and cons of each.


Why a Code Generator
--------------------

The question is: can you make a code generator that occupies less than the
Compressed code generated by crunchers_ like the alz64_ or the Exomizer_?

If it is *unrolled loops*, the answer is almost always yes. By two
Reasons:

- An unrolled loop is only a pattern that is repeated and repeated [#] with some
  bytes changed.
- While the c64 crunchers work well remember that the code * De-cruncher * has
  to run on the c64, occupy very little and be fast. And it is which is why they
  do not compress as well as modern compressors such as bzip2 or the xz_.


How to make a code generator
----------------------------

There is no black magic or anything strange. What you have to do is analyze the
bytes that one wants to generate, look for patterns and make a code that
generates those patterns. Whenever we want to generate code from an *unrolled
loop*, then let's be able to find a pattern.

For example, this is a memory dump of what we want to generate:

.. Figure: https://lh3.googleusercontent.com/eGInnhLFkmqw4SbOp54_kXuN-JVQetVtZ-kwSPEg2rHH7xZvyeYq1_Mm6AINS3xUiHLBkh1_SBo4B3BklbtP_zsfoNmLkFMZWYGy0G2Wez7uBGJzuHQXoUS6pcSwgWASrh-ENn3CzA8
    :Alt: memory dump


Let's analyze the first 3 bytes: ``2E 38 70``

- ``2E`` is the opcode of ``rol``
- ``38 70`` is the memory address in * little endian *: ``$7038``

And if we analyze the first 40 ``rols``:

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


Here is a clear pattern:

- The values of the first 8 ``rol`` are separated by ``-7``: ``$7038``,
  ``$7031``, ...
- The following 8 ``rol`` are the same as the previous 8, but their values are
  ``$100`` more. ``$100`` is a round number We like it!

And if we look again at our algorithm, we see that the bytes that
we see.

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


Mmm ... similar to the previous case, but with one important difference:

- The values of the first 7 ``rol`` are separated by ``-7``: ``$7039``,
  ``$7032``, ...
- The value of the following ``rol`` is separated by ``305`` (305 = 320 - 7 - 8)
  of the previous
- The following 8 `` roll`` are the same as the previous 8, but their values are
  ``$100`` higher (as with the first 40 ``roll``)

And if we quickly see the next 40 ``rol`` we see:


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

Similar to the previous 40 ``roll``.

- The values of the first 6 ``roll`` are separated by ``-7``: ``$703a``,
  ``$7033``, ...
- The value of the following ``rol`` is separated by ``305`` (305 = 320 - 7 - 8)
  of the previous
- The value of the following `` roll`` is separated by ``-7`` from the previous one
- The following 8 ``roll`` are the same as the previous 8, but their values are
  ``$100`` higher (as with the first 40 `` roll``)

And so...

Do you see the pattern? There are probably several ways to generate code that
we want. We ended up using tables of *base* + *offset*. It works
so:

.. code:: c

        // pseudo código

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

Let's see if it works for the values of the first row (* row 0 *):


.. code::

        //        gfx   + base + offset =
        valor 0 = $6f00 + $138 +    0 = $7038 ✔
        valor 1 = $6f00 + $130 +    1 = $7031 ✔
        ...
        valor 6 = $6f00 + $108 +    6 = $700e ✔
        valor 7 = $6f00 + $100 +    7 = $7007 ✔

        valor 8 = $6f00 +  $f8 + $140 = $7138 ✔

It seems to work ... let's see for the second row (* row 1 *):


.. code::

        //         gfx   + base + offset =
        valor 40 = $6f00 + $138 +    1 = $7039 ✔
        valor 41 = $6f00 + $130 +    2 = $7032 ✔
        ...
        valor 46 = $6f00 + $108 +    7 = $700f ✔
        valor 47 = $6f00 + $100 + $140 = $7140 ✔

        valor 48 = $6f00 +  $f8 + $141 = $7139 ✔

It works. And it also works for the 3rd row, 4th, etc. And in this way,
We have a ``roll`` value generator that works the way we want it to.

The complete assembler code is in `github <https://github.com/c64scene-ar/4kindness/blob/master/intro.s#L233>` __.
There is nothing strange except for this to calculate the values for the ``rol``
using the tables we saw. Something like this is:


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

And how much does code that generates code hold?

Unmolded:

- Using * unrolled loop *: ``2078 bytes``
- Using code generator: ``423 bytes``

Both tablets using alz64_:

- Using * unrolled loop *: ``730 bytes``
- Using code generator: ``260 bytes``

And those "470 bytes" of difference (730-260) were the ones that allowed us to do
That the intro occupy less than 4k! (I.e.


CONCLUSIONS
------------

- It is not common to have to generate code
- In case you need it, try to generate the unrolled * loops code as they usually take up a lot and have a pattern
- If mathematical operations are complicated to generate the pattern, use tables of calculation.


Questions and others
====================

Do you have questions? Do you want to collaborate with PVM? We're here:

-  http://pungas.space
-  On IRC. `EFnet <http://www.efnet.org/>`__ . Channel #pvm
-  `Twitter <https://twitter.com/pungas64>`__
-  `Facebook <https://www.facebook.com/PVM1996/>`__


References
==========

.. [#] El nombre en castellano es `bucle desenroscado <https://es.wikipedia.org/wiki/Desenroscado_de_bucles>`__ pero en este tutorial lo voy a seguir llamando *unrolled loop*
.. [#] Usamos `alz64 <http://csdb.dk/release/?id=77754>`__ para comprimir, ya que comprime mejor que Exomizer, pero es mucho más lento
.. [#] Se repite y se repite, me tiene re-podrido: `Ritmo de la Noche - The Sacados <https://genius.com/The-sacados-ritmo-de-la-noche-lyrics>`__

.. _Exomizer: https://bitbucket.org/magli143/exomizer/wiki/Home
.. _Parte_I: https://github.com/c64scene-ar/chipdisk-nac-vol.1/blob/master/chipdisk_internals.es.rst
.. _alz64: http://csdb.dk/release/?id=77754
.. _bounding-box: https://en.wikipedia.org/wiki/Minimum_bounding_box
.. _bzip2: http://www.bzip.org/
.. _cc65: https://github.com/cc65/cc65
.. _crunchers: http://iancoog.altervista.org/PACKERS.TXT
.. _xz: https://en.wikipedia.org/wiki/Xz
