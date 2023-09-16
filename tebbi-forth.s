# Copyright (c) 2023 Christopher Leonard
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

   .macro literal_zero
   sub   $4, %ebx
   mov   %eax, (%ebx)
   xor   %eax, %eax
   .endm

   .macro branch, else
   mov   %eax, %ecx
   mov   (%ebx), %eax
   add   $4, %ebx
   or    %ecx, %ecx
   jz    \else
   .endm

   .macro raw_of, endof
   mov   %eax, %ecx
   mov   (%ebx), %eax
   add   $4, %ebx
   cmp   (%ebx), %eax
   jne   \endof
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

   variable c_here, "CHERE", c_here_init
   variable h, "H", h_init
   variable state, "STATE", 0
   variable current, "CURRENT", forth_wordlist__data
   variable forth_wordlist, "FORTH-WORDLIST", last_def
   .long 0
   variable to_in, ">IN", 0
   variable number_tib, "\#TIB", 0
   variable exit_code, "EXIT-CODE", 0
   variable args, "ARGS", 0
   variable tick_find, "'FIND", raw_find
   variable tib, "TIB", 0
   .space   TIB_SIZE - 4

   value rp0, "RP0", 0

   header bye, "BYE", 0
   mov   $1, %eax
   mov   (exit_code__data), %ebx
   int   $0x80

   header sys_write, "SYS-WRITE", 0

   header sys_read, "SYS-READ", 0

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

   header star, "*", 0
   mull  (%ebx)
   add   $4, %ebx
   ret

   header zero_equals, "0=", 0
   mov   %eax, %ecx
   xor   %eax, %eax
   or    %ecx, %ecx
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
   mov   %eax, 4(%ebx)
   sub   $8, %ebx
   ret

   header c_store, "C!", 0
   mov   (%ebx), %ecx
   mov   %cl, (%eax)
   mov   %eax, 4(%ebx)
   sub   $8, %ebx
   ret

   header plus_store, "+!", 0
   mov   (%ebx), %ecx
   add   %ecx, (%eax)
   mov   4(%ebx), %eax
   sub   $8, %ebx
   ret

   header aligned, "ALIGNED", 0
   dec   %eax
   and   $-4, %eax
   inc   %eax
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

   header count, "COUNT", 0
   sub   $4, %ebx
   lea   1(%eax), %ecx
   mov   %ecx, (%ebx)
   movzxb (%eax), %eax
   ret

   # : NAME>STRING ( a-an)   8 +  COUNT  $3F AND ;
   header name_to_string, "NAME>STRING", 0
   literal 8
   call  plus
   call  count
   literal 0x3F
   call  and
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
6: branch 7f
   literal 1
7: ret
5: jmp 4b
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
4: branch 5f
   literal_zero
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

   # : -CREATE ( -a)
   #    BL WORD
   #    DUP 0= ABORT" expected name"
   #    ALIGN  HERE SWAP  CURRENT @ @ ,  CALIGN CHERE @ ,
   #    C@ ALLOT ALIGN ;
   header dash_create, "-CREATE", 0
   call  bl
   call  word
   call  dup
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

   # : LINK ( a)   CURRENT @ ! ;
   header link, "LINK", 0
   call  current
   call  fetch
   call  store
   ret

   # : GET ( -a)
   #    0
   #    BEGIN
   #       DROP BL WORD  DUP C@ 0= WHILE
   #       REFILL DROP
   #    REPEAT ;
   header get, "GET", 0
5:
   literal_zero
   call  drop
   call  bl
   call  word
   call  dup
   call  c_fetch
   call  zero_equals
   branch 6f
   call  refill
   call  drop
   jmp   5b
6:
   ret

   # : QUIT
   #    SP0 4 -  SP!
   #    0 STATE !
   #    BEGIN
   #       GET FIND
   #       STATE @ IF
   #          CASE -1 OF  EXECUTE   ENDOF
   #                1 OF  COMPILE,  ENDOF
   #               DROP   NUMBER,   END-CASE
   #       ELSE
   #          IF EXECUTE ELSE NUMBER THEN
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
6:
   jmp   4b
   ret

   # : ABORT   RP0 RP!  QUIT ;
   header abort, "ABORT", 0
   call  rp0
   call  rp_store
   call  quit
   ret

   # : EXIT   0xC1 CCODE, ; IMMEDIATE
   header exit, "EXIT", IMM
   literal 0xC1
   call  c_code_comma
   ret

   .globl start
   header start, "START", 0
   mov   %esp, (args__data)
   mov   %esp, (rp0__data)
   mov   $4, %eax
   mov   $1, %ebx
   mov   $5f, %ecx
   mov   $6f-5f, %edx
   int   $0x80
   jmp   quit
   ret
   .section .rodata
5:
   .ascii "hi "
6:

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
