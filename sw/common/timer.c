#include "mem_map.h"
#include "timer.h"

//--------------------------------------------------------------------------
// timer_init:
//--------------------------------------------------------------------------
void timer_init(void)
{
    // Not required
}
//--------------------------------------------------------------------------
// timer_sleep:
//--------------------------------------------------------------------------
void timer_sleep(int timeMs)
{
    t_time t = timer_now();

    while (timer_diff(timer_now(), t) < timeMs)
        ;
}
