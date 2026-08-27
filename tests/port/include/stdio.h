#ifndef PORT_STDIO_H
#define PORT_STDIO_H

int printf(const char *fmt, ...);
int scanf(const char *fmt, ...);
int sprintf(char *s, const char *fmt, ...);
int ee_printf(const char *fmt, ...);

char *strcpy(char *dest, const char *src);
int   strcmp(const char *s1, const char *s2);

#endif
