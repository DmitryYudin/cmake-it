    section .rodata
msg:
    db 'Hello from x64 assembly!',0

    section .text
    global message
message:
    mov rax, msg
    ret

%ifndef USER_DEFINE
bla bla bla
%endif
