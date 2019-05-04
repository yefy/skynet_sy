#include "skpMalloc.h"

void *SkpMalloc::malloc(const char *file, uint16 line, const char *function, int size)
{
    SKP_UNUSED(file);
    SKP_UNUSED(line);
    SKP_UNUSED(function);

    void *p = ::malloc(size);
    SKP_ASSERT(p);

    return p;
}


void *SkpMalloc::calloc(const char *file, uint16 line, const char *function, int size)
{
    void *p = SkpMalloc::malloc(file, line, function, size);
    SKP_ASSERT(p);
    if (p) {
        skp_memzero(p, size);
    }

    return p;
}

void *SkpMalloc::realloc(const char *file, uint16 line, const char *function, void *buffer, int size)
{
    SKP_UNUSED(file);
    SKP_UNUSED(line);
    SKP_UNUSED(function);
    void *p = ::realloc(buffer, size);
    SKP_ASSERT(p);
    return p;
}


#if (SKP_HAVE_POSIX_MEMALIGN)

void *SkpMalloc::memalign(const char *file, uint16 line, const char *function, int alignment, int size)
{
    SKP_UNUSED(file);
    SKP_UNUSED(line);
    SKP_UNUSED(function);

    void  *p;
    int    err;

    err = posix_memalign(&p, alignment, size);
    SKP_ASSERT(!err);

    return p;
}
#endif
