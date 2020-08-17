    .syntax unified
    .section .rodata
    .arch armv7-a
    .fpu neon
    .thumb
    .text

msg:
    .align  2
    .ascii "Hello from ARM32/THUMB2 assembly!\000"

    .align  2
    .thumb_func
    .global message
message:
    adr r0, msg
    bx lr
