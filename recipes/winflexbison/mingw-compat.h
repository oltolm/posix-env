/* Force-included when building winflexbison with mingw-w64 GCC: supplies
   what the MSVC build gets from MSVC itself or from its own config.  */
#ifndef MINGW_COMPAT_H
#define MINGW_COMPAT_H
#include <share.h>
#define _GL_ATTRIBUTE_FORMAT_PRINTF_STANDARD(a, b)
#ifndef min
#define min(a, b) ((a) < (b) ? (a) : (b))
#endif
#define ffsl __builtin_ffsl
#define htonl __builtin_bswap32
#define htons __builtin_bswap16
#endif
