    .section .rodata
    .text
.msg:
    .ascii "Hello from ARM64 assembly!\000"

    .align 2
    .global message
message:
    adrp    x0, .msg
    add x0, x0, :lo12:.msg
    ret
