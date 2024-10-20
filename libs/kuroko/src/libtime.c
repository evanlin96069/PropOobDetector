#include "libtime.h"

#if defined(_WIN32) && defined (__clang__)

#include <windows.h>

int clock_gettime(int clk_id, struct timespec *tp) {
    if (clk_id == CLOCK_REALTIME) {
        FILETIME ft;
        GetSystemTimeAsFileTime(&ft);
        ULARGE_INTEGER ull;
        ull.LowPart = ft.dwLowDateTime;
        ull.HighPart = ft.dwHighDateTime;
        tp->tv_sec = (ull.QuadPart / 10000000ULL) - 11644473600ULL; // Convert to Unix time
        tp->tv_nsec = (ull.QuadPart % 10000000ULL) * 100;
        return 0;
    } else if (clk_id == CLOCK_MONOTONIC) {
        LARGE_INTEGER freq, counter;
        QueryPerformanceFrequency(&freq);
        QueryPerformanceCounter(&counter);
        tp->tv_sec = counter.QuadPart / freq.QuadPart;
        tp->tv_nsec = (counter.QuadPart % freq.QuadPart) * 1000000000ULL / freq.QuadPart;
        return 0;
    }
    return -1; //
}

static struct tm tm;

struct tm *localtime_r(const time_t *timep, struct tm *result) {
    if (localtime_s(&tm, timep) == 0) {
        *result = tm;
        return &tm;
    }
    return NULL;
}

struct tm *gmtime_r(const time_t *timep, struct tm *result) {
if (gmtime_s(&tm, timep) == 0) {
        *result = tm;
        return &tm;
    }
    return NULL;
}

#endif