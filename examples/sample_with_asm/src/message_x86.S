    section .rodata
msg:
    db 'Hello from x86 assembly!',0

    section .text
    global _message
_message:
    mov eax, msg
    ret

%ifndef USER_DEFINE
bla bla bla
%endif
