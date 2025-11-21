#include "include/shim.h"

char *swift_tparm(const char *capability,
                  int32_t param1,
                  int32_t param2,
                  int32_t param3,
                  int32_t param4,
                  int32_t param5,
                  int32_t param6,
                  int32_t param7,
                  int32_t param8,
                  int32_t param9) {
    return tparm((char *)capability,
                 param1,
                 param2,
                 param3,
                 param4,
                 param5,
                 param6,
                 param7,
                 param8,
                 param9);
}
