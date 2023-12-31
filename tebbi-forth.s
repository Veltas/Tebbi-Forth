# Tebbi Forth - Copyright (c) 2023 Christopher Leonard
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following
# conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the
# Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY
# KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
# WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
# PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
# OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

   .equ DATA_STACK_SIZE, 4*64
   .equ DICTIONARY_SIZE, 0x800000
   .equ DICTIONARY_CODE_SIZE, DICTIONARY_SIZE
   .equ TIB_SIZE, 1024

   .equ IMM, 0x80

   .set link_previous, 0

   .macro header label, string, immediate
   .section .data
   .align 4
\label\()__header:
   .long link_previous
   .set link_previous, \label\()__header
   .long \label
   .byte (2f-1f) | (\immediate\())
1:
   .ascii "\string\()"
2:
   .align 4
\label\()__data:
   .text
   .align 4
\label\():
   .endm

   .macro variable label, string, value
   header \label\(), \string\(), 0
   sub   $4, %ebx
   mov   %eax, (%ebx)
   mov   $\label\()__data, %eax
   ret
   .data
   .long \value
   .endm

   .macro value label, string, value
   header \label\(), \string\(), 0
   sub   $4, %ebx
   mov   %eax, (%ebx)
   mov   (\label\()__data), %eax
   ret
   .data
   .long \value
   .endm

   .macro constant label, string, value
   header \label\(), \string\(), 0
   sub   $4, %ebx
   mov   %eax, (%ebx)
   mov   $\value\(), %eax
   ret
   .endm

   .macro literal value
   sub   $4, %ebx
   mov   %eax, (%ebx)
   mov   $(\value\()), %eax
   .endm

   .macro two_literal value
   sub   $8, %ebx
   mov   %eax, 4(%ebx)
   mov   $(\value\()) & 0xFFFFFFFF, %ecx
   mov   %ecx, (%ebx)
   mov   $(\value\()) >> 32, %eax
   .endm

   .macro literal_zero
   sub   $4, %ebx
   mov   %eax, (%ebx)
   xor   %eax, %eax
   .endm

   .macro two_literal_zero
   sub   $8, %ebx
   mov   %eax, 4(%ebx)
   xor   %eax, %eax
   mov   %eax, (%ebx)
   .endm

   .macro branch, else
   test  %eax, %eax
   mov   (%ebx), %eax
   lea   4(%ebx), %ebx
   jz    \else
   .endm

   .macro raw_of, endof
   cmp   (%ebx), %eax
   je    1f
   mov   (%ebx), %eax
   lea   4(%ebx), %ebx
   jmp   \endof
1: mov   4(%ebx), %eax
   lea   8(%ebx), %ebx
   .endm

   .macro string, content
   .data
1:
   .ascii "\content\()"
2:
   .text
   sub   $8, %ebx
   mov   %eax, 4(%ebx)
   mov   $2b-1b, %eax
   movl  $1b, (%ebx)
   .endm

   constant bl, "BL", 0x20
   constant tib_size, "TIB-SIZE", TIB_SIZE
   constant sp0, "SP0", sp0_init
   constant stdin, "STDIN", 0
   constant stdout, "STDOUT", 1

   variable c_here, "CHERE", c_here_init
   variable h, "H", h_init
   variable state, "STATE", 0
   variable base, "BASE", 10
   variable current, "CURRENT", forth_wordlist__data
   variable to_in, ">IN", 0
   variable number_tib, "\#TIB", 0
   variable exit_code, "EXIT-CODE", 0
   variable args, "ARGS", 0
   variable tick_find, "'FIND", find_tick
   variable tick_refill, "'REFILL", refill_tick
   variable tib, "TIB", 0
   .space   TIB_SIZE - 4

   value forth_wordlist, "FORTH-WORDLIST", last_def
   .long 0
   value rp0, "RP0", 0

   header bye, "BYE", 0
   mov   $1, %eax
   mov   (exit_code__data), %ebx
   int   $0x80

   # CODE SYS-WRITE ( ann-n)
   header sys_write, "SYS-WRITE", 0
   push  %ebx
   push  %eax
   mov   $4, %eax
   mov   (%ebx), %edx
   mov   4(%ebx), %ecx
   pop   %ebx
   int   $0x80
   pop   %ebx
   add   $8, %ebx
   ret

   # CODE SYS-READ ( ann-n)
   header sys_read, "SYS-READ", 0
   push  %ebx
   push  %eax
   mov   $3, %eax
   mov   4(%ebx), %ecx
   mov   (%ebx), %edx
   pop   %ebx
   int   $0x80
   pop   %ebx
   add   $8, %ebx
   ret

   header drop, "DROP", 0
   mov   (%ebx), %eax
   add   $4, %ebx
   ret

   header dup, "DUP", 0
   sub   $4, %ebx
   mov   %eax, (%ebx)
   ret

   header question_dup, "?DUP", 0
   or    %eax, %eax
   jz    1f
   sub   $4, %ebx
   mov   %eax, (%ebx)
1: ret

   header over, "OVER", 0
   mov   (%ebx), %ecx
   sub   $4, %ebx
   mov   %eax, (%ebx)
   mov   %ecx, %eax
   ret

   header swap, "SWAP", 0
   xchg  (%ebx), %eax
   ret

   header rot, "ROT", 0
   mov   (%ebx), %ecx
   mov   4(%ebx), %edx
   mov   %eax, (%ebx)
   mov   %ecx, 4(%ebx)
   mov   %edx, %eax
   ret

   header minus_rot, "-ROT", 0
   mov   (%ebx), %ecx
   mov   4(%ebx), %edx
   mov   %eax, 4(%ebx)
   mov   %edx, (%ebx)
   mov   %ecx, %eax
   ret

   header nip, "NIP", 0
   add   $4, %ebx
   ret

   header tuck, "TUCK", 0
   mov   (%ebx), %ecx
   sub   $4, %ebx
   mov   %eax, 4(%ebx)
   mov   %ecx, (%ebx)
   ret

   header two_dup, "2DUP", 0
   mov   (%ebx), %ecx
   sub   $8, %ebx
   mov   %eax, 4(%ebx)
   mov   %ecx, (%ebx)
   ret

   header two_drop, "2DROP", 0
   mov   4(%ebx), %eax
   add   $8, %ebx
   ret

   header two_swap, "2SWAP", 0
   mov   8(%ebx), %ecx
   mov   (%ebx), %edx
   xchg  4(%ebx), %eax
   mov   %ecx, (%ebx)
   mov   %edx, 8(%ebx)
   ret

   header to_r, ">R", 0
   pop   %ecx
   push  %eax
   push  %ecx
   mov   (%ebx), %eax
   add   $4, %ebx
   ret

   header r_from, "R>", 0
   sub   $4, %ebx
   mov   %eax, (%ebx)
   pop   %ecx
   pop   %eax
   push  %ecx
   ret

   header rp_tick, "RP'", 0
   sub   $4, %ebx
   mov   %eax, (%ebx)
   lea   4(%esp), %eax
   ret

   header one_plus, "1+", 0
   inc   %eax
   ret

   header one_minus, "1-", 0
   dec   %eax
   ret

   header plus, "+", 0
   add   (%ebx), %eax
   add   $4, %ebx
   ret

   header minus, "-", 0
   sub   (%ebx), %eax
   neg   %eax
   add   $4, %ebx
   ret

   # CODE D+ ( NN-N)
   header d_plus, "D+", 0
   mov   (%ebx), %ecx
   add   %ecx, 8(%ebx)
   adc   4(%ebx), %eax
   add   $8, %ebx
   ret

   header d_minus, "D-", 0
   mov   (%ebx), %ecx
   sub   %ecx, 8(%ebx)
   mov   4(%ebx), %ecx
   sbb   %eax, %ecx
   mov   %ecx, %eax
   add   $8, %ebx
   ret

   header negate, "NEGATE", 0
   neg   %eax
   ret

   header d_negate, "DNEGATE", 0
   xor   %ecx, %ecx
   negl  (%ebx)
   sbb   %eax, %ecx
   mov   %ecx, %eax
   ret

   header star, "*", 0
   mull  (%ebx)
   add   $4, %ebx
   ret

   # CODE UM* ( Nn-N)
   header u_m_star, "UM*", 0
   mov   %eax, %ecx
   mov   4(%ebx), %eax
   mul   %ecx
   mov   %eax, 4(%ebx)
   mov   (%ebx), %eax
   push  %edx
   mul   %ecx
   pop   %edx
   add   %edx, %eax
   add   $4, %ebx
   ret

   header zero_equals, "0=", 0
   mov   %eax, %ecx
   xor   %eax, %eax
   or    %ecx, %ecx
   setz  %al
   neg   %eax
   ret

   header d_zero_equals, "D0=", 0
   mov   %eax, %ecx
   xor   %eax, %eax
   or    (%ebx), %ecx
   setz  %al
   neg   %eax
   ret

   header zero_not_equals, "0<>", 0
   mov   %eax, %ecx
   xor   %eax, %eax
   or    %ecx, %ecx
   setnz %al
   neg   %eax
   ret

   header equals, "=", 0
   mov   %eax, %ecx
   xor   %eax, %eax
   cmp   %ecx, (%ebx)
   sete  %al
   neg   %eax
   add   $4, %ebx
   ret

   header not_equals, "<>", 0
   mov   %eax, %ecx
   xor   %eax, %eax
   cmp   %ecx, (%ebx)
   setne %al
   neg   %eax
   add   $4, %ebx
   ret

   header less_than, "<", 0
   mov   %eax, %ecx
   xor   %eax, %eax
   cmp   %ecx, (%ebx)
   setl  %al
   neg   %eax
   add   $4, %ebx
   ret

   header greater_than, ">", 0
   mov   %eax, %ecx
   xor   %eax, %eax
   cmp   %ecx, (%ebx)
   setg  %al
   neg   %eax
   add   $4, %ebx
   ret

   header u_less, "U<", 0
   mov   %eax, %ecx
   xor   %eax, %eax
   cmp   %ecx, (%ebx)
   setb  %al
   neg   %eax
   add   $4, %ebx
   ret

   header u_greater, "U>", 0
   mov   %eax, %ecx
   xor   %eax, %eax
   cmp   %ecx, (%ebx)
   seta  %al
   neg   %eax
   add   $4, %ebx
   ret

   header and, "AND", 0
   and   (%ebx), %eax
   add   $4, %ebx
   ret

   header or, "OR", 0
   or    (%ebx), %eax
   add   $4, %ebx
   ret

   header xor, "XOR", 0
   xor   (%ebx), %eax
   add   $4, %ebx
   ret

   header invert, "INVERT", 0
   not   %eax
   ret

   header fetch, "@", 0
   mov   (%eax), %eax
   ret

   header c_fetch, "C@", 0
   movzxb (%eax), %eax
   ret

   header store, "!", 0
   mov   (%ebx), %ecx
   mov   %ecx, (%eax)
   mov   4(%ebx), %eax
   add   $8, %ebx
   ret

   header c_store, "C!", 0
   mov   (%ebx), %ecx
   mov   %cl, (%eax)
   mov   4(%ebx), %eax
   add   $8, %ebx
   ret

   header plus_store, "+!", 0
   mov   (%ebx), %ecx
   add   %ecx, (%eax)
   mov   4(%ebx), %eax
   add   $8, %ebx
   ret

   header aligned, "ALIGNED", 0
   dec   %eax
   and   $-4, %eax
   add   $4, %eax
   ret

   header execute, "EXECUTE", 0
   mov   %eax, %ecx
   mov   (%ebx), %eax
   add   $4, %ebx
   jmp   *%ecx

   header sp_store, "SP!", 0
   mov   %eax, %ebx
   mov   (%ebx), %eax
   add   $4, %ebx
   ret

   header rp_store, "RP!", 0
   pop   %ecx
   mov   %eax, %esp
   push  %ecx
   mov   (%ebx), %eax
   add   $4, %ebx
   ret

   header compare, "COMPARE", 0
   push  %esi
   push  %edi
   mov   8(%ebx), %esi
   mov   (%ebx), %edi
   mov   %eax, %ecx
   mov   4(%ebx), %edx
   cmp   %edx, %eax
   cmovg %edx, %ecx
   repe cmpsb
   jne   4f
   cmp   %edx, %eax
   jne   5f
   xor   %eax, %eax
   jmp   6f
5:
   jl    5f
   mov   $-1, %eax
   jmp   6f
5: mov   $1, %eax
   jmp   6f
4: jb    5f
   mov   $1, %eax
   jmp   6f
5: mov   $-1, %eax
   jmp   6f
6: add   $12, %ebx
   pop   %edi
   pop   %esi
   ret

   header cmove, "CMOVE", 0
   push  %esi
   push  %edi
   mov   4(%ebx), %esi
   mov   (%ebx), %edi
   mov   %eax, %ecx
   rep movsb
   mov   8(%ebx), %eax
   add   $12, %ebx
   pop   %edi
   pop   %esi
   ret

   header cmove_up, "CMOVE>", 0
   push  %esi
   push  %edi
   mov   4(%ebx), %esi
   mov   (%ebx), %edi
   mov   %eax, %ecx
   std
   rep movsb
   cld
   mov   8(%ebx), %eax
   add   $12, %ebx
   pop   %edi
   pop   %esi
   ret

   header count, "COUNT", 0
   sub   $4, %ebx
   lea   1(%eax), %ecx
   mov   %ecx, (%ebx)
   movzxb (%eax), %eax
   ret

   # CODE WITHIN ( nnn-?)
   header within, "WITHIN", 0
   push  %esi
   mov   4(%ebx), %edx
   mov   (%ebx), %ecx
   xor   %esi, %esi
   sub   %ecx, %edx
   sub   %ecx, %eax
   cmp   %eax, %edx
   mov   %esi, %eax
   setb  %al
   neg   %eax
   pop   %esi
   add   $8, %ebx
   ret

   # : /STRING ( ann-an)   TUCK - -ROT + SWAP ;
   header slash_string, "/STRING", 0
   call  tuck
   call  minus
   call  minus_rot
   call  plus
   call  swap
   ret

   # : DIGIT>NUMBER ( c-n|100)
   #    DUP 'a' < 0= IF
   #       'a' - 'A' +
   #    THEN
   #    DUP 'A' 'Z' 1+ WITHIN IF
   #       'A' - 10 +
   #    ELSE  DUP '0' '9' 1+ WITHIN IF
   #       '0' -
   #    ELSE
   #       DROP 100
   #    THEN THEN ;
   header digit_to_number, "DIGIT>NUMBER", 0
   call  dup
   literal 'a'
   call  less_than
   call  zero_equals
   branch 4f
   literal 'a'
   call  minus
   literal 'A'
   call  plus
4: call  dup
   literal 'A'
   literal 'Z'
   call  one_plus
   call  within
   branch 4f
   literal 'A'
   call  minus
   literal 10
   call  plus
   jmp   5f
4: call  dup
   literal '0'
   literal '9'
   call  one_plus
   call  within
   branch 6f
   literal '0'
   call  minus
   jmp   5f
6: call  drop
   literal 100
5: ret

   # : DIGIT? ( c-?)  DIGIT>NUMBER BASE @ < ;
   header digit_question, "DIGIT?", 0
   call  digit_to_number
   call  base
   call  fetch
   call  less_than
   ret

   # : >NUMBER ( Nan-Nan)
   #    BEGIN
   #       DUP WHILE
   #       OVER C@ DIGIT? WHILE
   #       OVER C@ DIGIT>NUMBER >R
   #       2SWAP BASE @ UM* R> 0 D+ 2SWAP
   #       1 /STRING
   #    REPEAT THEN ;
   header to_number, ">NUMBER", 0
4: call  dup
   branch 4f
   call  over
   call  c_fetch
   call  digit_question
   branch 4f
   call  over
   call  c_fetch
   call  digit_to_number
   call  to_r
   call  two_swap
   call  base
   call  fetch
   call  u_m_star
   call  r_from
   literal_zero
   call  d_plus
   call  two_swap
   literal 1
   call  slash_string
   jmp   4b
4: ret

   # : ALIGN   HERE ALIGNED H ! ;
   header align, "ALIGN", 0
   call  here
   call  aligned
   call  h
   call  store
   ret

   # : CALIGN   CHERE @ ALIGNED CHERE ! ;
   header c_align, "CALIGN", 0
   call  c_here
   call  fetch
   call  aligned
   call  c_here
   call  store
   ret

   # : ALLOT ( n)   H +! ;
   header allot, "ALLOT", 0
   call  h
   call  plus_store
   ret

   # : COMPILE, ( e)
   #    $E8 CCODE,
   #    CHERE @ 4 +  -  CODE, ;
   header compile_comma, "COMPILE,", 0
   literal 0xE8
   call  c_code_comma
   call  c_here
   call  fetch
   literal 4
   call  plus
   call  minus
   call  code_comma
   ret

   # : TYPE   STDOUT SYS-WRITE DROP ;
   header type, "TYPE", 0
   call  stdout
   call  sys_write
   call  drop
   ret

   # : SPACE   S" " TYPE ;
   header space, "SPACE", 0
   string " "
   call  type
   ret

   # : CR   S\" \n" TYPE ;
   header cr, "CR", 0
   string "\n"
   call  type
   ret

   # : (ABORT") ( ?an)
   #    ROT IF SPACE TYPE CR ABORT
   #    ELSE 2DROP THEN ;
   header raw_abort_quote, "(ABORT\")", 0
   call  rot
   branch 4f
   call  space
   call  type
   call  cr
   call  abort
   jmp   5f
4: call  two_drop
5: ret

   # : NAME>STRING ( a-an)   8 +  COUNT  $3F AND ;
   header name_to_string, "NAME>STRING", 0
   literal 8
   call  plus
   call  count
   literal 0x3F
   call  and
   ret

   # : NAME>INTERPRET ( a-e)   4 + @ ;
   header name_to_interpret, "NAME>INTERPRET", 0
   literal 4
   call  plus
   call  fetch
   ret

   # : IMM? ( a-?)   8 +  C@  $80 AND 0<> ;
   header imm_question, "IMM?", 0
   literal 8
   call  plus
   call  c_fetch
   literal 0x80
   call  and
   call  zero_not_equals
   ret

   # : CCODE, ( c)   C-HERE @  1 C-HERE +!  C! ;
   header c_code_comma, "CCODE,", 0
   call  c_here
   call  fetch
   literal 1
   call  c_here
   call  plus_store
   call  c_store
   ret

   # : CODE, ( n)   C-HERE @  4 C-HERE +!  ! ;
   header code_comma, "CODE,", 0
   call  c_here
   call  fetch
   literal 4
   call  c_here
   call  plus_store
   call  store
   ret

   # : HERE ( a)   H @ ;
   header here, "HERE", 0
   call  h
   call  fetch
   ret

   # : C, ( c)   HERE  1 H +!  C! ;
   header c_comma, "C,", 0
   call  here
   literal 1
   call  h
   call  plus_store
   call  c_store
   ret

   # : , ( x)   HERE  4 H +!  ! ;
   header comma, ",", 0
   call  here
   literal 4
   call  h
   call  plus_store
   call  store
   ret

   # : FIND' ( a - a 0 | e 1 | e -1 )
   #    CURRENT @ @
   #    BEGIN DUP WHILE
   #       2DUP SWAP COUNT ROT NAME>STRING COMPARE 0= IF
   #          NIP
   #          DUP NAME>INTERPRET
   #          SWAP IMM? IF -1 ELSE 1 THEN
   #          EXIT
   #       THEN
   #       @
   #    REPEAT ;
   header find_tick, "FIND'", 0
   call  current
   call  fetch
   call  fetch
4: call  dup
   branch 4f
   call  two_dup
   call  swap
   call  count
   call  rot
   call  name_to_string
   call  compare
   call  zero_equals
   branch 5f
   call  nip
   call  dup
   call  name_to_interpret
   call  swap
   call  imm_question
   branch 6f
   literal -1
   jmp   7f
6: literal 1
7: ret
5: call  fetch
   jmp 4b
4: ret

   # : FIND ( a - a 0 | e 1 | e -1 )   'FIND @ EXECUTE ;
   header find, "FIND", 0
   call  tick_find
   call  fetch
   call  execute
   ret

   # : PEEK-IN ( c|0)
   #    >IN @ #TIB @ < IF
   #       TIB >IN @ + C@
   #    ELSE
   #       0
   #    THEN ;
   header peek_in, "PEEK-IN", 0
   call  to_in
   call  fetch
   call  number_tib
   call  fetch
   call  less_than
   branch 4f
   call  tib
   call  to_in
   call  fetch
   call  plus
   call  c_fetch
   jmp   5f
4: literal_zero
5: ret

   # : GET-IN ( c|0)   PEEK-IN  DUP IF  1 >IN +!  THEN ;
   header get_in, "GET-IN", 0
   call  peek_in
   call  dup
   branch 4f
   literal 1
   call  to_in
   call  plus_store
4: ret

   # : SKIP-DELIM ( c)
   #    BEGIN
   #       PEEK-IN ?DUP WHILE
   #       OVER = WHILE
   #       1 >IN +!
   #    REPEAT THEN
   #    DROP ;
   header skip_delim, "SKIP-DELIM", 0
4: call  peek_in
   call  question_dup
   branch 4f
   call  over
   call  equals
   branch 4f
   literal 1
   call  to_in
   call  plus_store
   jmp   4b
4: call  drop
   ret

   # : 'WORD ( -a)   HERE ALIGNED 8 + ;
   header tick_word, "'WORD", 0
   call  here
   call  aligned
   literal 8
   call  plus
   ret

   # : PARSE ( c-an)
   #    TIB >IN @ + SWAP
   #    >IN @ SWAP
   #    BEGIN
   #       PEEK-IN WHILE
   #       DUP PEEK-IN <> WHILE
   #       1 >IN +!
   #    REPEAT THEN
   #    DROP
   #    >IN @ SWAP -
   #    GET-IN DROP ;
   header parse, "PARSE", 0
   call  tib
   call  to_in
   call  fetch
   call  plus
   call  swap
   call  to_in
   call  fetch
   call  swap
4: call  peek_in
   branch 4f
   call  dup
   call  peek_in
   call  not_equals
   branch 4f
   literal 1
   call  to_in
   call  plus_store
   jmp   4b
4: call  drop
   call  to_in
   call  fetch
   call  swap
   call  minus
   call  get_in
   call  drop
   ret

   # : WORD ( c-a)
   #    DUP SKIP-DELIM  PARSE  DUP 255 > ABORT" word too long"
   #    TUCK  'WORD 1+ SWAP CMOVE
   #    'WORD C!  'WORD ;
   header word, "WORD", 0
   call  dup
   call  skip_delim
   call  parse
   call  dup
   literal 255
   call  greater_than
   string "word too long"
   call  raw_abort_quote
   call  tuck
   call  tick_word
   call  one_plus
   call  swap
   call  cmove
   call  tick_word
   call  c_store
   call  tick_word
   ret

   # : KEY ( -c)   0 >R RP' 1 STDIN SYS-READ DROP R> ;
   header key, "KEY", 0
   literal_zero
   call  to_r
   call  rp_tick
   literal 1
   call  stdin
   call  sys_read
   call  drop
   call  r_from
   ret

   # : REFILL' ( -?)
   #    CR
   #    0 >IN !
   #    0 #TIB !
   #    BEGIN
   #       0
   #       #TIB @ TIB-SIZE < WHILE
   #       DROP KEY
   #       DUP 10 <> WHILE
   #       TIB #TIB @ + C!
   #       1 #TIB +!
   #    REPEAT THEN
   #    DROP -1 ;
   header refill_tick, "REFILL'", 0
   call  cr
   literal_zero
   call  to_in
   call  store
   literal_zero
   call  number_tib
   call  store
4: literal_zero
   call  number_tib
   call  fetch
   call  tib_size
   call  less_than
   branch 4f
   call  drop
   call  key
   call  dup
   literal 10
   call  not_equals
   branch 4f
   call  tib
   call  number_tib
   call  fetch
   call  plus
   call  c_store
   literal 1
   call  number_tib
   call  plus_store
   jmp   4b
4: call  drop
   literal -1
   ret

   # : REFILL ( -?)   'REFILL @ EXECUTE ;
   header refill, "REFILL", 0
   call  tick_refill
   call  fetch
   call  execute
   ret

   # : GET ( -a)
   #    0
   #    BEGIN
   #       DROP BL WORD  DUP C@ 0= WHILE
   #       REFILL DROP
   #    REPEAT ;
   header get, "GET", 0
   literal_zero
5: call  drop
   call  bl
   call  word
   call  dup
   call  c_fetch
   call  zero_equals
   branch 6f
   call  refill
   call  drop
   jmp   5b
6: ret

   # : SEPARATOR? ( c-?)
   #    CASE '.' OF ENDOF
   #         ',' OF ENDOF
   #         ''' OF ENDOF
   #         '-' OF ENDOF
   #         ':' OF ENDOF
   #         DROP 0 EXIT ENDCASE
   #    -1 ;
   header separator_question, "SEPARATOR?", 0
   literal '.'
   raw_of 4f
   jmp   5f
4: literal ','
   raw_of 4f
   jmp   5f
4: literal '\''
   raw_of 4f
   jmp   5f
4: literal '-'
   raw_of 4f
   jmp   5f
4: literal ':'
   raw_of 4f
   jmp   5f
4: call  drop
   literal_zero
   ret
5: literal -1
   ret

   # : HUH?   SPACE 'WORD COUNT TYPE ." ?" ABORT ;
   header huh_question, "HUH?", 0
   call  space
   call  tick_word
   call  count
   call  type
   string "?"
   call  type
   call  abort
   ret

   # : DNUMBER ( Nan-N)
   #    BEGIN >NUMBER DUP WHILE
   #       OVER C@ SEPARATOR? 0= IF HUH? THEN
   #       1 /STRING
   #    REPEAT
   #    2DROP ;
   header d_number, "DNUMBER", 0
4: call  to_number
   call  dup
   branch 4f
   call  over
   call  c_fetch
   call  separator_question
   call  zero_equals
   branch 5f
   call  huh_question
5: literal 1
   call  slash_string
   jmp   4b
4: call  two_drop
   ret

   # : NUMBER ( a-n0|Nt)
   #    COUNT
   #    OVER C@ '-' =  DUP IF 1 /STRING THEN  >R
   #    0. 2SWAP >NUMBER
   #    DUP IF 2NUMBER -1 ELSE 2DROP 0 THEN
   #    R> IF DNEGATE THEN
   #    DUP 0= IF NIP THEN ;
   header number, "NUMBER", 0
   call  count
   call  over
   call  c_fetch
   literal '-'
   call  equals
   call  dup
   branch 4f
   literal 1
   call  slash_string
4: call  to_r
   two_literal_zero
   call  two_swap
   call  to_number
   call  dup
   branch 4f
   call  d_number
   literal -1
   jmp   5f
4: call  two_drop
   literal_zero
5: call  r_from
   branch 4f
   call  d_negate
4: call  dup
   call  zero_equals
   branch 4f
   call  nip
4: ret

   # : LIT-TOS ( n)
   #    ?DUP IF
   #       $B8 CCODE, CODE,              \ mov eax, n
   #    ELSE
   #       $31 CCODE, $C0 CCODE,         \ xor eax, eax
   #    THEN ;
   header lit_tos, "LIT-TOS", 0
   call  question_dup
   branch 4f
   literal 0xB8
   call  c_code_comma
   call  code_comma
   jmp   5f
4: literal 0x31
   call  c_code_comma
   literal 0xC0
   call  c_code_comma
5: ret

   # : LITERAL ( n)
   #    $83 CCODE, $EB CCODE, $04 CCODE, \ sub ebx, 4
   #    $89 CCODE, $03 CCODE,            \ mov [ebx], eax
   #    LIT-TOS ; IMMEDIATE
   header literal, "LITERAL", IMM
   literal 0x83
   call  c_code_comma
   literal 0xEB
   call  c_code_comma
   literal 0x04
   call  c_code_comma
   literal 0x89
   call  c_code_comma
   literal 0x03
   call  c_code_comma
   call  lit_tos
   ret

   # : 2LITERAL ( N)
   #    $83 CCODE, $EB CCODE, $08 CCODE, \ sub ebx, 8
   #    $89 CCODE, $43 CCODE, $04 CCODE, \ mov [ebx+4], eax
   #    2DUP D0= IF
   #       2DROP
   #       $31 CCODE, $C0 CCODE,         \ xor eax, eax
   #       $89 CCODE, $03 CCODE,         \ mov [ebx], eax
   #    ELSE
   #       SWAP ?DUP IF
   #          $B9 CCODE, CODE,          \ mov ecx, n
   #       ELSE
   #          $31 CCODE, $C9 CCODE,      \ xor ecx, ecx
   #       THEN
   #       $89 CCODE, $0B CCODE,         \ mov [ebx], ecx
   #       LIT-TOS
   #    THEN ; IMMEDIATE
   header two_literal, "2LITERAL", IMM
   literal 0x83
   call  c_code_comma
   literal 0xEB
   call  c_code_comma
   literal 0x08
   call  c_code_comma
   literal 0x89
   call  c_code_comma
   literal 0x43
   call  c_code_comma
   literal 0x04
   call  c_code_comma
   call  two_dup
   call  d_zero_equals
   branch 4f
   call  two_drop
   literal 0x31
   call  c_code_comma
   literal 0xC0
   call  c_code_comma
   literal 0x89
   call  c_code_comma
   literal 0x03
   call  c_code_comma
   jmp   5f
4: call  swap
   call  question_dup
   branch 6f
   literal 0xB9
   call  c_code_comma
   literal 0xB9
   call  code_comma
   jmp 7f
6: literal 0x31
   call  c_code_comma
   literal 0xC9
   call  c_code_comma
7: literal 0x89
   call  c_code_comma
   literal 0x0B
   call  c_code_comma
   call  lit_tos
5: ret

   # : NUMBER, ( a)
   #    NUMBER IF
   #       POSTPONE 2LITERAL
   #    ELSE
   #       POSTPONE LITERAL
   #    THEN ;
   header number_comma, "NUMBER,", 0
   call  number
   branch 4f
   call  two_literal
   jmp   5f
4: call  literal
5: ret

   # : QUIT
   #    SP0 4 -  SP!
   #    0 STATE !
   #    REFILL DROP
   #    BEGIN
   #       GET FIND
   #       STATE @ IF
   #          CASE -1 OF  EXECUTE   ENDOF
   #                1 OF  COMPILE,  ENDOF
   #               DROP   NUMBER,   ENDCASE
   #       ELSE
   #          IF EXECUTE ELSE NUMBER DROP THEN
   #       THEN
   #    AGAIN ;
   header quit, "QUIT", 0
   call  sp0
   literal 4
   call  minus
   call  sp_store
   literal_zero
   call  state
   call  store
   call  refill
   call  drop
4: call  get
   call  find
   call  state
   call  fetch
   branch 5f
   literal -1
   raw_of 6f
   call  execute
   jmp   7f
6: literal 1
   raw_of 6f
   call  compile_comma
   jmp   7f
6: call  drop
   call  number_comma
7: jmp   6f
5: branch 7f
   call  execute
   jmp   6f
7:
   call  number
   call  drop
6:
   jmp   4b
   ret

   # : ABORT   RP0 RP!  QUIT ;
   header abort, "ABORT", 0
   call  rp0
   call  rp_store
   call  quit
   ret

   .globl start
   header start, "START", 0
   mov   %esp, args__data
   mov   %esp, rp0__data
   xor   %eax, %eax
   mov   $sp0_init, %ebx
   jmp   quit

   # : ]   1 STATE ! ;
   header right_bracket, "]", 0
   literal 1
   call  state
   call  store
   ret

   # : [   0 STATE ! ; IMMEDIATE
   header left_bracket, "[", IMM
   literal_zero
   call  state
   call  store
   ret

   # : CREATE' ( -a)
   #    BL WORD
   #    DUP C@ 0= ABORT" expected name"
   #    ALIGN  HERE SWAP  CURRENT @ @ ,  CALIGN CHERE @ ,
   #    C@ ALLOT ALIGN ;
   header create_tick, "CREATE'", 0
   call  bl
   call  word
   call  dup
   call  c_fetch
   call  zero_equals
   string "expected name"
   call  raw_abort_quote
   call  align
   call  here
   call  swap
   call  current
   call  fetch
   call  fetch
   call  comma
   call  c_align
   call  c_here
   call  fetch
   call  comma
   call  c_fetch
   call  allot
   call  align
   ret

   # : EXIT   0xC1 CCODE, ; IMMEDIATE
   header exit, "EXIT", IMM
   literal 0xC3
   call  c_code_comma
   ret

   # : ' ( -e)
   #    BL WORD  FIND 0= IF HUH? THEN ;
   header tick, "\'", 0
   call  bl
   call  word
   call  find
   call  zero_equals
   branch 4f
   call  huh_question
4: ret

   # Allocate room for runtime-generated code in modifiable,
   # executable page.
   .section .xtext, "awx", @nobits
c_here_init:
   .skip DICTIONARY_CODE_SIZE

   # Allocate room for runtime-generated data at end of BSS.
   .bss
h_init:
   .skip DICTIONARY_SIZE

   # Allocate room for runtime data stack.
   .bss
   .align 4
   .long 0 # 2 overflow padding cells
   .long 0
   .skip DATA_STACK_SIZE
   .align 4
sp0_init:
   .long 0 # 2 underflow padding cells
   .long 0

   # Get value of last_def
   .equ last_def, link_previous
