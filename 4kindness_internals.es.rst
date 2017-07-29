Cursito intermedio de asm para la c64 - Parte II: Haciendo una intro 4k
=======================================================================

:Versión: 0.1.0 (`ir a última versión <https://github.com/c64scene-ar/puas/blob/master/4kindness_internals.es.rst>`__)
:Autor: `riq <http://retro.moe>`__ / `Pungas de Villa Martelli <http://pungas.space>`__

.. contents:: Contenidos
   :depth: 2

Introducción
============

Hola. Primero bajarse el 4Kindness para darse una idea de lo que abarca esta
parte del cursito:

-  `4kindness.d64 <https://github.com/c64scene-ar/4kindness/raw/master/bin/4kindness.d64>`__

Listo, empecemos. Solo dos cosas que vamos a estudiar:

- Como hacer un scroll en diagonal
- Como generar código


Scroll en diagonal
==================

En la Parte_I_ vimos como hacer un scroll con sprites. Es un buen momento para
releerlo en caso que no lo tengan fresco:

- `Como hacer un scroll con sprites <https://github.com/c64scene-ar/chipdisk-nac-vol.1/blob/master/chipdisk_internals.es.rst#scroll-con-sprites>`__

Hacer un scroll con sprites hi-res, ó en modo gráfico hi-res es básimante
similar. Repasemos el modo gráfico hi-res.

- Esta compuesto por 40 x 25 celdas.


.. Figure:: https://lh3.googleusercontent.com/K_YyuNocoS4yaVxr2uuJgraYpI5An3BwgxahScn3bDjdFBsLj4b6h-g4ngUxkbOfXqlkpSQuQIKeGGEgVgrsShnI5FnIl8GSKw8msFEYmGatIrfTKp_5RpFPTsmgZYZ1N-2fH3T1QMc
   :alt: bitmap cells

- Cada celda ocupa 8 bytes

.. Figure:: https://lh3.googleusercontent.com/lqU7dLG2RpCfhoZ-pw2L3zNjkLVOgsjAdHxM5JtYnLy7gwO7K7i-lxRawKgyKhloBcvO3IzZ1vl36sthotpo7DSFIhdj7X9-qbnbh5Bp8OjjwajeKwcwOouhZgqqDKL4amN1TwRczac
   :alt: cell detail

Si queremos hacer un scroll horizontal en modo gráfico hi-res, solo tenemos que
hacer ``rol`` (rotate left) de los bytes en un orden determinado, ya que el
``carry flag`` se tiene que propagar de un byte a otro.

Supongamos que el bitmap esta la posición ``$6000`` y queremos scrollear la
primer fila de celdas (las 8 primeras filas de bits de arriba), entonces un
posible código sería:

.. code:: asm

        ; variables
        BITMAP_ADDR = $6000
        cell_x0_0  = BITMAP_ADDR +  0 * 8 + 0
        cell_x0_1  = BITMAP_ADDR +  0 * 8 + 1
        ...
        cell_x39_6 = BITMAP_ADDR + 39 * 8 + 6
        cell_x39_7 = BITMAP_ADDR + 39 * 8 + 7
        ...

        ; rotate left row 0
        jsr get_carry_value
        rol cell_x39_0
        rol cell_x38_0
        ...
        rol cell_x1_0
        rol cell_x0_0

        ; rotate left row 1
        jsr get_carry_value
        rol cell_x39_1
        rol cell_x38_1
        ...
        rol cell_x1_1
        rol cell_x0_1

        ; rotate left row 7
        jsr get_carry_value
        rol cell_x39_7
        rol cell_x38_7
        ...
        rol cell_x1_7
        rol cell_x0_7


El código se puede reducir mucho usando haciendo un *unrolled loop* con las
poderosas macros del ensamblador. (Ver
`unrolled loops <https://github.com/c64scene-ar/chipdisk-nac-vol.1/blob/master/chipdisk_internals.es.rst#truquito-unrolled-loops>`__ 
de la Parte I)
Algo así:


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

Y listo! Sencillo, ¿no?
Ahora que sabemos hacer un scroll horizontal usando bitmap, ¿cómo hacemos para
que el scroll sea en diagonal?

La idea es similar. El scroll que queremos hacer tiene que tener la siguiente
pendiente:

TODO: gráfico

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

``y``: por cada 8 ``rol``s, se incrementa en 1
``x``: por cada ``rol``, se decrementa en 1
``offset``: por cada ``rol``, se incrementa en 1. Con valores entre 0 y 7. O sea, módulo 8.

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
ensamblador sin macros ni unrolled loops. Van a ver que rápido que se complica.

**Repito**: Algoritmos que son fáciles de escribir en C, pero difíciles de
escribir en ensamblador __puro__, se pueden convertir de manera relativamente
sencilla a ensamblador con unrolled loops + macros.

No solamente es más fácil de hacer, sino que la velocidad de ejecución
¡va a ser mucho mayor! (y además el código es más mantenible).


Pero se paga un precio alto en usar unrolled loops: memoria RAM. Un simple
loop que quizas ocupa unas decenas de bytes, cuando se convierte a unrolled loop
puede ocupar unos miles de bytes.

En la Parte_I_ usamos unrolled loops para ganar performance. En este caso usamos
unrolled loops para simplificar el algoritmo (y de paso mejorar la performance).

Es un trade off:

- memoria RAM vs. performance + sencillez del algoritmo

    .. note:: El algoritmo se puede escribir en C tranquilimante. De hecho
      nosotros usamos cc65_ como ensamblador. Y mezclar C con ensamblador puede 
      resultar muy útil. Pero esta fuera del alcance del "cursito de asm"
      cuando y como usar C.

Generar código
==============

4Kindness, este scroller que hicimos, fue para presentarlo en un concurso de
intros de 4k. Esto significa que el binario no puede ocupar más de 4096 bytes.
Pero en memoria puede ocupar todo lo que quiera. De hecho en memoria la intro
ocupa ~16K RAM:

- gráfico bitmap: 9k
- música SID: 2.5k
- fonts: 1k
- código: 2.5k (de los cuales 2k eran del unrolled loop)

Cuando comprimimos todo [#]_, nos quedó un binario de 5k.

Pudimos reducir un poco la música, los fonts y usando la Zero Page estabamos en
los ~4.5k. Mucho más no podíamos reducir el binario sin reducir esos 2k de
código generados por el unrolled loop.

Tomamos 3 estrategias diferentes:

- Hacer el loop en C
- Hacer un generador de código en C
- Hacer un generador de código en ensamblador

No recuerdo que sucedió con el loop en C (no se si era lento ó que no tuvimos
tiempo ó que), pero la cosa es que nos dividimos el trabajo y uno hizo un
generador en C y otro en asm.

Las dos generadores funcionarion bien, pero el que estaba hecho en asm era un
poco más chico que el hecho en C, y por eso usamos el de asm.


Cómo se hace un generador de código
-----------------------------------

No hay mágia ni nada raro. Lo que hay que hacer es analizar los bytes que uno
quiere generar y buscar patrones y hacer un código que genere esos patrones.

Agarramos un editor hexadecimal, y veíamos esos bytes hasta encontrar un patrón.

TODO: gráfico.



Referencias
===========

.. [#] Usamos `alz64 <http://csdb.dk/release/?id=77754>`__ para comprimir, ya que comprime mejor que Exomizer, pero es mucho más lento

.. _Parte_I: https://bitbucket.org/magli143/exomizer/wiki/Home
.. _cc65: https://github.com/cc65/cc65
