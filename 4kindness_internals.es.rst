Cursito intermedio de asm para la c64 - Parte II: Haciendo una intro 4k
=======================================================================

:Versión: 0.1.0 (`ir a última versión <https://github.com/c64scene-ar/4kindness/blob/master/4kindness_internals.es.rst>`__)
:Autor: `riq <http://retro.moe>`__ / `Pungas de Villa Martelli <http://pungas.space>`__

.. contents:: Contenidos
   :depth: 2

Introducción
============

Hola. Esto es lo que hace la intro 4Kindness:

.. Figure:: https://lh3.googleusercontent.com/y3C0o2PzEErAfDILRZSLyG9wV9HNSk58Udk-k--r6T80yqFkpny995jARy_4mFHKoiXjs8I2nfJhXbv3XNvRxjzWt-IYfZjQBVIn_t8KCNuHT4oVMQLnn-OJtLQSDiDk-jrs2OADaMs
   :alt: Intro 4Kindness

Y el binario lo pueden bajar de acá: `4kindness.d64 <https://github.com/c64scene-ar/4kindness/raw/master/bin/4kindness.d64>`__.
Y el código fuente esta acá: `4Kindness en github <https://github.com/c64scene-ar/4kindness>`__

Listo, empecemos. Solo dos cosas que vamos a estudiar:

- Como hacer un scroll en diagonal
- Como generar código


Scroll en diagonal
==================

En la Parte_I_ vimos como hacer un scroll con sprites. Es un buen momento para
releerlo en caso que no lo tengan fresco: `Como hacer un scroll con sprites <https://github.com/c64scene-ar/chipdisk-nac-vol.1/blob/master/chipdisk_internals.es.rst#scroll-con-sprites>`__

Hacer un scroll con sprites hi-res, ó en modo gráfico hi-res es básicamante
lo mismo. Repasemos el modo gráfico hi-res.

- Esta compuesto por 40 x 25 celdas:

.. Figure:: https://lh3.googleusercontent.com/K_YyuNocoS4yaVxr2uuJgraYpI5An3BwgxahScn3bDjdFBsLj4b6h-g4ngUxkbOfXqlkpSQuQIKeGGEgVgrsShnI5FnIl8GSKw8msFEYmGatIrfTKp_5RpFPTsmgZYZ1N-2fH3T1QMc
   :alt: bitmap cells

- Cada celda ocupa 8 bytes:

.. Figure:: https://lh3.googleusercontent.com/lqU7dLG2RpCfhoZ-pw2L3zNjkLVOgsjAdHxM5JtYnLy7gwO7K7i-lxRawKgyKhloBcvO3IzZ1vl36sthotpo7DSFIhdj7X9-qbnbh5Bp8OjjwajeKwcwOouhZgqqDKL4amN1TwRczac
   :alt: cell detail


En total ocupa 40 celdas * 8 bytes c/u * 25 celdas = 8000 bytes. Más la memoria
para el color que son otros 1000 bytes (pero que no nos interesa para hacer el
scroll).

Si queremos hacer un scroll horizontal en modo gráfico hi-res, solo tenemos que
hacer ``rol`` (*rotate left*) de los bytes en un orden determinado, ya que el
*carry flag* se tiene que propagar de un byte a otro.

.. Figure:: https://lh3.googleusercontent.com/oEBuQcNd5kJmrhFS9MVPtRaaRMS6Mbe_TqzaAmzlz8q7fPY-_GsicScFhf5gtop6_3ifH0kG-4EIpJtUmvdIJnK0wlURmVk1wMCqhR_FPzY47z2BlOZZsBzPBK41c_CKzXPtRZywA9c
   :alt: horizontal scroll

Supongamos que queremos scrollear la primer fila de celdas (las 8 primeras filas
de bits de arriba), entonces un posible código sería:

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


El código se puede reducir mucho usando haciendo un *unrolled loop* [#]_ con las
poderosas macros del ensamblador (ver
`unrolled loops <https://github.com/c64scene-ar/chipdisk-nac-vol.1/blob/master/chipdisk_internals.es.rst#truquito-unrolled-loops>`__
de la Parte I). Sería algo así:


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

¡Y listo! Sencillo, ¿no?
Ahora que sabemos hacer un scroll horizontal usando bitmap, ¿cómo hacemos para
que el scroll sea en diagonal?

La idea es similar. El scroll que queremos hacer tiene que tener la siguiente
pendiente:

.. Figure:: https://lh3.googleusercontent.com/EBZt0OIIXfiSuHnllmPaAYNJeGQ0tm7U7b-lT1MX_JOgGzrpDODhGHHeHa4MS5ErBbeyQ8XFK9MxTRCR9kPNB7D8b-XuJJo4P_HMz3cdpX3uiVTykr2XNZ0spJhvZBqyVoRAmvWa7EE

En estos casos ayuda escribir "a mano" como se tiene que comportar el scroll.
Para scrollear solo la primer fila de bits, hay que hacer:

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


Y ahora tenemos que convertir eso en un algoritmo. Tenemos 3 variables.
Analicemos los patrones:

- ``y``: por cada 8 ``rol``, se incrementa en 1
- ``x``: por cada ``rol``, se decrementa en 1
- ``offset``: por cada ``rol``, se incrementa en 1. Con valores entre 0 y 7. O sea, módulo 8.

En pseudo código sería:

.. code:: c

        // scroll en diagonal de la primer fila de bits
        for (int i=0; i<40; i++) {
            y = i / 8;
            x = 39 - i;
            offset = i % 8;

            addr = BITMAP_ADDR + 320 * y + 8 * x + offset;
            rol(addr);
        }

Y para que funcione para los 8 primeras filas de bits, se agrega un loop más:

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

Y ahora hay que pasarlo a ensamblador:

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

¡Listo! Y quiero resaltar lo fácil que es escribir algoritmos usando **unrolled
loops + macros**. Ejercicio para el lector: convertir ese algoritmo a
ensamblador sin macros ni *unrolled loops*. Van a ver que rápido que se
complica.

**Repito**: Algoritmos que son fáciles de escribir en C, pero difíciles de
escribir en ensamblador *puro*, se pueden convertir de manera relativamente
sencilla a ensamblador con *unrolled loops* + macros.

No solamente es más fácil de hacer, sino que la velocidad de ejecución
¡va a ser mucho mayor! (y además el código es más mantenible).

Pero se paga un precio alto en usar *unrolled loops*: memoria RAM. Un simple
loop que quizás ocupa unas decenas de bytes, cuando se convierte a *unrolled
loop* puede ocupar unos miles de bytes.

En la Parte_I_ usamos *unrolled loops* para ganar velocidad de ejecución. En
este caso usamos *unrolled loops* para simplificar el código (y de paso
mejorar la velocidad de ejecución).

Es un compromiso: memoria RAM ó velocidad de ejecución & código más prolijo

    .. note:: El algoritmo se puede escribir tranquilamente en C. De hecho
      nosotros usamos cc65_ como ensamblador. Y mezclar C con ensamblador puede
      resultar muy útil. Pero esta fuera del alcance del "cursito de asm"
      el como usar C.

Generar código
==============

4Kindness, este scroller que hicimos, fue para presentarlo en un concurso de
intros de 4k. Esto significa que el binario no puede ocupar más de 4096 bytes.
Pero en memoria puede ocupar todo lo que quiera. De hecho 4Kindness, en memoria,
ocupa ~16K RAM:

- gráfico bitmap: 9k
- música SID: 2.5k
- fonts: 1k
- código: 2.5k (de los cuales 2k eran del *unrolled loop*)

Cuando comprimimos todo [#]_, nos quedó un binario de ~5k.

Pudimos reducir un poco la música, los fonts y usando la Zero Page estábamos en
los ~4.5k. Mucho más no podíamos reducir el binario sin reducir esos 2k de
código generados por el *unrolled loop*.

Consideramos 4 posibles alternativas:

- Hacer el loop en C
- Hacer el loop en ensamblador
- Hacer un generador de código en C
- Hacer un generador de código en ensamblador

Terminamos usando el generador de código en ensamblador. Pero las otras 3
alternativas eran válidas. Cuento esto, porque casi siempre hay más de una
posible solución. Es cuestión de analizar los pros y las contras de cada una.

Por qué un generador de código
------------------------------

La pregunta es: ¿se puede hacer un generador de código que ocupe menos que el
código comprimido generado por crunchers_ como el alz64_ o el Exomizer_?

Si se trata de *unrolled loops*, la respuesta es casi siempre sí. Por dos
motivos:

- Un *unrolled loop* no es más que un patrón que se repite y se repite [#]_ con
  algunos bytes cambiados.
- Si bien los crunchers_ de la c64 funcionan bien recordemos que el código del
  *de-cruncher* tiene que correr en la c64, ocupar muy poco y ser rápido. Y es
  por eso que no comprimen tan bien como compresores modernos como el bzip2_ ó
  el xz_.


Cómo se hace un generador de código
-----------------------------------

No hay mágia negra ni nada raro. Lo que hay que hacer es analizar los bytes que
uno quiere generar, buscar patrones y hacer un código que genere esos patrones.
Siempre que querramos generar código de un *unrolled loop*, entonces vamos a
poder encontrar un patrón.

Por ejemplo, esto es un dump de memoria de lo que queremos generar:

.. Figure:: https://lh3.googleusercontent.com/eGInnhLFkmqw4SbOp54_kXuN-JVQetVtZ-kwSPEg2rHH7xZvyeYq1_Mm6AINS3xUiHLBkh1_SBo4B3BklbtP_zsfoNmLkFMZWYGy0G2Wez7uBGJzuHQXoUS6pcSwgWASrh-ENn3CzA8
   :alt: memory dump


Analicemos los 3 primeros bytes: ``2E 38 70``

- ``2E`` es el opcode de ``rol``
- ``38 70`` es la dirección de memoria en *little endian*: ``$7038``

Y si analizamos los primeros 40 ``rols``:

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


Acá se ve un patrón claro:

- Los valores de los 8 primeros ``rol`` están separados por ``-7``:
  ``$7038``, ``$7031``, ...
- Los siguientes 8 ``rol`` son iguales a los 8 anteriores, pero sus valores son
  ``$100`` mayores. ``$100`` es un número redondo ¡Nos gusta!

Y si miramos nuevamente nuestro algoritmo, vemos que tiene sentido los bytes que
vemos.

Veamos que pasa con los siguientes 40 ``rol``:

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

        ...

Mmm... parecido al caso anterior, pero con una importante diferencia:

- Los valores de los 7 primeros ``rol`` están separadas por ``-7``: ``$7039``,
  ``$7032``, ...
- El valor del siguiente ``rol`` esta separado por ``305`` (305 = 320 - 7 - 8)
  del anterior
- Los siguientes 8 ``rol`` son iguales a los 8 anteriores, pero sus valores son
  ``$100`` mayores (igual que con los primeros 40 ``rol``)

Y si vemos rápidamente los siguiente 40 ``rol`` vemos:

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

Similar a los 40 ``rol`` anteriores.

- Los valores de los 6 primeros ``rol`` están separados por ``-7``: ``$703a``,
  ``$7033``, ...
- El valor del siguiente ``rol`` esta separado por ``305`` (305 = 320 - 7 - 8)
  del anterior
- El valor del siguiente ``rol`` esta separado por ``-7`` del anterior
- Los siguiente 8 ``rol`` son iguales a los 8 anteriores, pero sus valores son
  ``$100`` mayores (igual que con los primeros 40 ``rol``)

Y así...

¿Se ve el patrón? Probablemente haya varias maneras de generar el código que
queremos. Nosotros terminamos usando unas tablas de *base* + *offset*. Funciona
así:

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

Veamos si funciona para los valores de la primer fila (*row 0*):

.. code::

        //        gfx   + base + offset =
        valor 0 = $6f00 + $138 +    0 = $7038 ✔
        valor 1 = $6f00 + $130 +    1 = $7031 ✔
        ...
        valor 6 = $6f00 + $108 +    6 = $700e ✔
        valor 7 = $6f00 + $100 +    7 = $7007 ✔

        valor 8 = $6f00 +  $f8 + $140 = $7138 ✔


Parece funcionar... veamos para los de la segunda fila (*row 1*):

.. code::

        //         gfx   + base + offset =
        valor 40 = $6f00 + $138 +    1 = $7039 ✔
        valor 41 = $6f00 + $130 +    2 = $7032 ✔
        ...
        valor 46 = $6f00 + $108 +    7 = $700f ✔
        valor 47 = $6f00 + $100 + $140 = $7140 ✔

        valor 48 = $6f00 +  $f8 + $141 = $7139 ✔


Sí, funciona. Y también funciona para la 3ra fila, 4ta, etc. Y de esta manera,
tenemos un generador de valores para el ``rol`` que funciona como queremos.

El código en ensamblador completo esta en `github <https://github.com/c64scene-ar/4kindness/blob/master/intro.s#L233>`__.
No tiene nada de raro salvo esto de calcular los valores para los ``rol`` usando
las tablas que vimos. Algo así es:

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

¿Y cuanto ocupa el código que genera código?

Sin comprimir:

- Usando *unrolled loop*: ``2078 bytes``
- Usando generador de código: ``423 bytes``

Ambos comprimidos usando alz64_:

- Usando *unrolled loop*: ``730 bytes``
- Usando generador de código: ``260 bytes``

Y esos ``470 bytes`` de diferencia (730-260) fueron los que nos permitieron hacer
que la intro ocupe menos de 4k! :-)


Conclusiones
------------

- No es común tener que generar código
- En caso de necesitarlo, tratar de generar el código de los *unrolled loops* ya que suelen ocupar mucho y tienen un patrón
- Si se complican las operaciones matemáticas para generar el patrón, usar tablas de cálculo.


Preguntas y demás
=================

¿Tenés preguntas? ¿Querés colaborar con PVM? Estamos acá:

-  http://pungas.space
-  `Twitter <https://twitter.com/pungas64>`__
-  `Facebook <https://www.facebook.com/PVM1996/>`__
-  En IRC. `EFnet <http://www.efnet.org/>`__ . Canal #pvm

Referencias
===========

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
