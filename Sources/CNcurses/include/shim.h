#ifndef CNCURSES_SHIM_H
#define CNCURSES_SHIM_H

#include <curses.h>
#include <term.h>
#include <stdint.h>

char *swift_tparm(const char *capability,
                  int32_t param1,
                  int32_t param2,
                  int32_t param3,
                  int32_t param4,
                  int32_t param5,
                  int32_t param6,
                  int32_t param7,
                  int32_t param8,
                  int32_t param9);

#endif /* CNCURSES_SHIM_H */
