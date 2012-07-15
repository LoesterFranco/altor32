#ifndef __OS_ASSERT_H__
#define __OS_ASSERT_H__

// To disable RTOS assertions then define OS_RELEASE_MODE

//-----------------------------------------------------------------
// DEBUG
//-----------------------------------------------------------------
#ifndef OS_RELEASE_MODE

    extern void _thread_assert(const char *reason, const char *file, int line);

    #define OS_ASSERT(exp)      do { if (!(exp)) _thread_assert(#exp, __FILE__, __LINE__); } while (0)
    #define OS_PANIC(reason)    _thread_assert(reason, __FILE__, __LINE__)

//-----------------------------------------------------------------
// RELEASE
//-----------------------------------------------------------------
#else

    #define OS_ASSERT(exp)     ((void)0)
    #define OS_PANIC(reason)   while (1)

#endif

#endif

