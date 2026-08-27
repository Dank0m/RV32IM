#ifndef PORT_STRING_H
#define PORT_STRING_H

typedef unsigned int size_t;

char *strcpy(char *dest, const char *src);
int   strcmp(const char *s1, const char *s2);
void *memcpy(void *dest, const void *src, size_t n);
void *memset(void *s, int c, size_t n);

#endif
