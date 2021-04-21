    global _main
    extern _printf

    section .data

filename: db "train.csv", 0
format_string: db "%s", 10, 0
file_descriptor: dq 0
file_length: dq 0
file_contents: db 0

    section .text

_main:
    push rbp
    mov rbp, rsp

    ; int open(user_addr_t path, int flags, int mode)
    mov rax, 0x2000005
    mov rdi, filename
    xor rsi, rsi 			; O_RDONLY = 0
    xor rdx, rdx 			; mode is ignored
    syscall
    mov [rel file_descriptor], rax

    ; off_t lseek(int fd, off_t offset, int whence)
    mov rax, 0x20000C7
    mov rdi, [rel file_descriptor]
    xor rsi, rsi 
    mov rdx, 2				; SEEK_END
    syscall
    mov [rel file_length], rax		; file length

    ; off_t lseek(int fd, off_t offset, int whence)
    mov rax, 0x20000C7
    mov rdi, [rel file_descriptor]
    xor rsi, rsi
    xor rdx, rdx			; SEEK_SET
    syscall

    ; user_addr_t mmap(caddr_t addr, size_t len, int prot, int flags, int fd, off_t pos)
    mov rax, 0x20000C5
    xor rdi, rdi			; NULL
    mov rsi, [rel file_length]
    mov rdx, 3				; PROT_READ | PROT_WRITE
    mov rcx, 34				; MAP_PRIVATE | MAP_ANONYMOUS
    mov r8, -1
    mov r9, 0
    mov r10, 0x1002
    syscall
    mov [rel file_contents], rax

    ; user_ssize_t read(int fd, user_addr_t cbuf, user_size_t nbyte)
    mov rax, 0x2000003
    mov rdi, [rel file_descriptor]
    mov rsi, [rel file_contents]
    mov rdx, [rel file_length]
    syscall

    ; int close(int fd)
    mov rax, 0x2000006
    mov rdi, [rel file_descriptor]
    syscall

    ; printf(format_string, ...)
    mov rdi, format_string
    mov rsi, [rel file_contents]
    xor rax, rax
    call _printf

    ; void exit(int rval)
    mov rax, 0x2000001
    mov rdi, 0
    syscall
