#ifndef PORT_SYS_TIMES_H
#define PORT_SYS_TIMES_H

#ifndef HZ
#define HZ 100
#endif

struct tms {
    long tms_utime;
    long tms_stime;
    long tms_cutime;
    long tms_cstime;
};

int times();

#endif
