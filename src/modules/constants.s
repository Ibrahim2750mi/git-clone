# a0
.equ AT_FDCWD,         -100
.equ STDOUT,           1

# a7
.equ SYS_MKDIRAT,      34
.equ SYS_OPENAT,       56
.equ SYS_CLOSE,        57
.equ SYS_GETDENTS64,   61
.equ SYS_READ,         63
.equ SYS_WRITE,        64
.equ SYS_EXIT,         93

# a0/a2
.equ O_RDONLY,         0
.equ O_WRONLY,         1
.equ O_CREAT,          64
.equ O_TRUNC,          512
.equ O_DIRECTORY,      65536
.equ O_NOFOLLOW,       131072

.equ DT_DIR,           4
.equ DT_REG,           8
.equ EEXIST,           17
.equ EIO,              5

.equ BUFFER_SIZE,      4096
.equ COPY_BUFFERS,     8192
