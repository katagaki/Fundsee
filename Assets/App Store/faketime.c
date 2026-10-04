#include <time.h>
#include <sys/time.h>
#include <stdlib.h>
#include <CoreFoundation/CoreFoundation.h>

#define DYLD_INTERPOSE(_replacement,_replacee) \
  __attribute__((used)) static struct{ const void* replacement; const void* replacee; } _interpose_##_replacee \
  __attribute__ ((section ("__DATA,__interpose"))) = { (const void*)(unsigned long)&_replacement, (const void*)(unsigned long)&_replacee };

static double offset_seconds(void) {
  static int inited = 0; static double off = 0;
  if (!inited) {
    inited = 1;
    const char *e = getenv("FAKE_EPOCH");
    if (e) { struct timespec ts; clock_gettime(CLOCK_REALTIME, &ts); off = atof(e) - (double)ts.tv_sec; }
  }
  return off;
}

static int my_clock_gettime(clockid_t id, struct timespec *tp) {
  int r = clock_gettime(id, tp);
  if (r == 0 && id == CLOCK_REALTIME) tp->tv_sec += (time_t)offset_seconds();
  return r;
}
static int my_gettimeofday(struct timeval *tv, void *tz) {
  int r = gettimeofday(tv, tz);
  if (r == 0 && tv) tv->tv_sec += (time_t)offset_seconds();
  return r;
}
static time_t my_time(time_t *t) {
  time_t v = time(NULL) + (time_t)offset_seconds();
  if (t) *t = v; return v;
}
static CFAbsoluteTime my_CFAbsoluteTimeGetCurrent(void) {
  return CFAbsoluteTimeGetCurrent() + offset_seconds();
}
static uint64_t my_clock_gettime_nsec_np(clockid_t id) {
  uint64_t v = clock_gettime_nsec_np(id);
  if (id == CLOCK_REALTIME) v += (uint64_t)(offset_seconds() * 1e9);
  return v;
}
DYLD_INTERPOSE(my_clock_gettime, clock_gettime)
DYLD_INTERPOSE(my_gettimeofday, gettimeofday)
DYLD_INTERPOSE(my_time, time)
DYLD_INTERPOSE(my_CFAbsoluteTimeGetCurrent, CFAbsoluteTimeGetCurrent)
DYLD_INTERPOSE(my_clock_gettime_nsec_np, clock_gettime_nsec_np)
