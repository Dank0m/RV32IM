#include <stdarg.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/times.h>

#ifndef DHRY_RUNS
#define DHRY_RUNS 5
#endif

static unsigned char heap[4096];
static unsigned int  heap_off;

void *malloc(size_t n)
{
    size_t align_n = (n + 3u) & ~3u;
    if (heap_off + align_n > sizeof(heap)) {
        return 0;
    }
    void *p = &heap[heap_off];
    heap_off += (unsigned int)align_n;
    return p;
}

void free(void *p)
{
    (void)p;
}

char *strcpy(char *dest, const char *src)
{
    char *d = dest;
    while ((*d++ = *src++)) {
    }
    return dest;
}

int strcmp(const char *s1, const char *s2)
{
    while (*s1 && (*s1 == *s2)) {
        s1++;
        s2++;
    }
    return (unsigned char)*s1 - (unsigned char)*s2;
}

void *memcpy(void *dest, const void *src, size_t n)
{
    unsigned char *d = dest;
    const unsigned char *s = src;
    while (n--) {
        *d++ = *s++;
    }
    return dest;
}

void *memset(void *s, int c, size_t n)
{
    unsigned char *p = s;
    while (n--) {
        *p++ = (unsigned char)c;
    }
    return s;
}

int printf(const char *fmt, ...)
{
    (void)fmt;
    return 0;
}

int sprintf(char *s, const char *fmt, ...)
{
    (void)s;
    (void)fmt;
    return 0;
}

int scanf(const char *fmt, ...)
{
    va_list ap;
    int *n;
    (void)fmt;
    va_start(ap, fmt);
    n = va_arg(ap, int *);
    va_end(ap);
    *n = DHRY_RUNS;
    return 1;
}

int ee_printf(const char *fmt, ...)
{
    (void)fmt;
    return 0;
}

int times(buf)
struct tms *buf;
{
    if (buf) {
        buf->tms_utime  = 0;
        buf->tms_stime  = 0;
        buf->tms_cutime = 0;
        buf->tms_cstime = 0;
    }
    return 0;
}

unsigned __floatsisf(int x) { (void)x; return 0; }
unsigned __divsf3(unsigned a, unsigned b) { (void)a; (void)b; return 0; }
unsigned __mulsf3(unsigned a, unsigned b) { (void)a; (void)b; return 0; }
unsigned long long __extendsfdf2(unsigned a) { (void)a; return 0; }
unsigned long long __divdf3(unsigned long long a, unsigned long long b)
{
    (void)a;
    (void)b;
    return 0;
}
unsigned long long __muldf3(unsigned long long a, unsigned long long b)
{
    (void)a;
    (void)b;
    return 0;
}
unsigned __truncdfsf2(unsigned long long a) { (void)a; return 0; }
