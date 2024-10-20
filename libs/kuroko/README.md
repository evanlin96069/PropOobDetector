# Kuroko for Zig

This is a fork of [Kuroko](https://github.com/kuroko-lang/kuroko/) with zig bindings. Unnecessary files have been deleted, and the build system has been replaced with `build.zig`.

Modifications were made to ensure compatibility with `zig cc` on Windows.

To allow redirection of interpreter output, the following functions have been added, which the user must define:
```c
extern size_t krk_fwrite(void const* buffer, size_t elementSize, size_t elementCount, FILE* stream); 

extern int krk_fflush(FILE* stream);
```
