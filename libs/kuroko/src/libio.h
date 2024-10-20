#pragma once
/**
 * @file libio.h
 * @brief Custom IO functions.
 */
#include <stdio.h>

// User-defined functions

extern size_t krk_fwrite(void const* buffer, size_t elementSize, size_t elementCount, FILE* stream); 

extern int krk_fflush(FILE* stream);

// Some languages might not has a good way of getting stdout or stderr

extern FILE* krk_getStdout(void);

extern FILE* krk_getStderr(void);

// IO functions implemented using krk_fwrite

extern int krk_fprintf(FILE* stream, const char* fmt, ...);

extern int krk_fputc(int c, FILE* stream);
