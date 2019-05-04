#ifndef SKPMALLOC_H
#define SKPMALLOC_H

#include "skpUtility.h"

#define SKP_HAVE_POSIX_MEMALIGN 1

#define skp_memzero(buf, n)       (void) ::memset(buf, 0, n)
#define skp_memset(buf, c, n)     (void) ::memset(buf, c, n)
#define skp_malloc(size)    SkpMalloc::malloc(__FILE__, __LINE__, __FUNCTION__, size)
#define skp_calloc(size)    SkpMalloc::calloc(__FILE__, __LINE__, __FUNCTION__, size)
#define skp_memalign(alignment, size)    SkpMalloc::memalign(__FILE__, __LINE__, __FUNCTION__, alignment, size)
#define skp_realloc(buf, size) SkpMalloc::realloc(buf, size)
#define skp_free(p) \
        if(p) { \
            ::free(p); \
            (p) =  skp_null; \
        }

class SkpMalloc
{
public:
    static void *malloc(const char *file, uint16 line, const char *function, int size);
    static void *calloc(const char *file, uint16 line, const char *function, int size);
    static void *realloc(const char *file, uint16 line, const char *function, void *buffer, int size);

    /*
     * Linux has memalign() or posix_memalign()
     * Solaris has memalign()
     * FreeBSD 7.0 has posix_memalign(), besides, early version's malloc()
     * aligns allocations bigger than page size at the page boundary
     */

#if (SKP_HAVE_POSIX_MEMALIGN)
    static void *memalign(const char *file, uint16 line, const char *function, int alignment, int size);
#endif
};


#endif // SKPMALLOC_H
