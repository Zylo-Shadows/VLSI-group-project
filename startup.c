#include <stdint.h>
#include <string.h>

// from the linker
extern unsigned long _estack;
extern unsigned long _end;

__attribute__((section(".init"), naked))
void _reset_handler(void) {
  __asm__ volatile("mv sp, %0" : : "r" ((uint32_t)&_estack) : "memory");
  asm volatile("j _start");
  __builtin_unreachable();
}

char *__brkval = (char *)&_end;

//__attribute__((weak))
void * _sbrk(int incr)
{
  char *prev = __brkval;
  if (incr != 0) {
    //if (prev + incr > (char *)&_heap_end) {
    if (0) {
      return (void *)-1;
    }
    __brkval = prev + incr;
  }
  return prev;
}

__attribute__((weak))
int _read(int file __attribute__((unused)), char *ptr __attribute__((unused)), int len __attribute__((unused)))
{
	return 0;
}

__attribute__((weak))
int _close(int fd __attribute__((unused)))
{
	return -1;
}

#include <sys/stat.h>

__attribute__((weak))
int _fstat(int fd __attribute__((unused)), struct stat *st)
{
	st->st_mode = S_IFCHR;
	return 0;
}

__attribute__((weak))
int _isatty(int fd __attribute__((unused)))
{
	return 1;
}

__attribute__((weak))
int _lseek(int fd __attribute__((unused)), long long offset __attribute__((unused)), int whence __attribute__((unused)))
{
	return -1;
}

__attribute__((weak))
void _exit(int status __attribute__((unused)))
{
	while (1) asm ("WFI");
}

__attribute__((weak))
void abort(void)
{
	while (1) asm ("WFI");
}
