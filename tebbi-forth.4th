REFILL   Tebbi Forth - Copyright (c) 2023 Christopher Leonard
REFILL
REFILL   Permission is hereby granted, free of charge, to any
REFILL   person obtaining a copy of this software and
REFILL   associated documentation files (the "Software"), to
REFILL   deal in the Software without restriction, including
REFILL   without limitation the rights to use, copy, modify,
REFILL   merge, publish, distribute, sublicense, and/or sell
REFILL   copies of the Software, and to permit persons to whom
REFILL   the Software is furnished to do so, subject to the
REFILL   following conditions:
REFILL
REFILL   The above copyright notice and this permission notice
REFILL   shall be included in all copies or substantial
REFILL   portions of the Software.
REFILL
REFILL   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF
REFILL   ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
REFILL   LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
REFILL   FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
REFILL   EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
REFILL   FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
REFILL   AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
REFILL   FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE
REFILL   USE OR OTHER DEALINGS IN THE SOFTWARE.

ABORT

CREATE' ;
   ' EXIT COMPILE,
   ' [ COMPILE,
   ] CURRENT @ !
   EXIT [ CURRENT @ !

   CURRENT @ @ 8 +  DUP @ 128 OR  SWAP !

CREATE' :   ] CREATE' ] ;

: HEX   16 BASE ! ;
: DECIMAL   10 BASE ! ;

HEX

: IMMEDIATE
   CURRENT @ @ 8 +
   DUP @ 80 OR  SWAP ! ;

: (   41 PARSE 2DROP ; IMMEDIATE
: \   #TIB @ >IN ! ; IMMEDIATE

: [COMPILE]   ' COMPILE, ; IMMEDIATE

\ a1 = origin eip
: IF ( -a)
   85 CCODE, C0 CCODE, \ test eax, eax
   8B CCODE, 03 CCODE, \ mov  eax, [ebx]
   8D CCODE, 5B CCODE, \ lea  ebx, [ebx+4]
   74 CCODE, 00 CCODE, \ jz   0
   CHERE @ ; IMMEDIATE

\ a1 = origin eip
\ a2 = destination eip
: LINK-BRANCH ( aa)   OVER -  SWAP 1- C! ;

\ a1 = origin eip
: THEN ( a)   CHERE @ LINK-BRANCH ; IMMEDIATE

\ a1 = IF origin eip
\ a2 = ELSE origin eip
: ELSE ( a-a)
   EB CCODE, 00 CCODE, \ jmp  0
   CHERE @ SWAP
   CHERE @ LINK-BRANCH ; IMMEDIATE

\ a1 = destination eip
: BEGIN ( -a)   CHERE @ ; IMMEDIATE

\ a1 = BEGIN destination eip
\ a2 = WHILE origin eip
\ a3 = a1
: WHILE ( a-aa)   [COMPILE] IF  SWAP ; IMMEDIATE

\ a1 = WHILE origin eip
\ a2 = BEGIN destination eip
: REPEAT ( aa)
   EB CCODE,  CHERE @ 1+ - CCODE, \ jmp  destination
   [COMPILE] THEN ; IMMEDIATE

: UNTIL ( a-)   [COMPILE] IF  SWAP LINK-BRANCH ; IMMEDIATE

DECIMAL

: CHAR   BL WORD  1+ C@ ;
: [CHAR]   CHAR [COMPILE] LITERAL ; IMMEDIATE

: ABORT"
   [CHAR] " PARSE  [COMPILE] SLITERAL
   [COMPILE] (ABORT") ;  IMMEDIATE

: (   [CHAR] ^ PARSE  2DROP ;
: \   0 PARSE  2DROP ;
