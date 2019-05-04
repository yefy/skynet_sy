#ifndef SKPMALLOCPOOLEX_H
#define SKPMALLOCPOOLEX_H

#include "skpUtility.h"
#include "skpQueue.h"

#define skp_pool_calloc(pool, size) (pool)->calloc(__FILE__, __LINE__, __FUNCTION__, size)

#define skp_pool_free(pool, p) \
        if((pool) && (p)) { \
            (pool)->free(__FILE__, __LINE__, __FUNCTION__, p); \
            (p) =  NULL; \
        }

typedef struct skp_pool_ex_s skp_pool_ex_t;
typedef struct skp_pool_align_head_s skp_pool_align_head_t;
typedef struct skp_pool_large_ex_s skp_pool_large_ex_t;

class SkpMallocPoolEx
{
public:
    SkpMallocPoolEx(int size = 0);
    ~SkpMallocPoolEx();


    void reset();
    void *malloc(const char *file, uint16 line, const char *function, int size);
    void *calloc(const char *file, uint16 line, const char *function, int size);
    bool free(const char *file, uint16 line, const char *function, void *p);
    bool write(void *dest, const void *src, int size);
    int read(const void *src, void *dest, int size);
    bool memset(void *dest, int data, int size);
    int  size();

private:
    skp_pool_ex_t *create(int size);
    void destroy();
    void *doMalloc(int size, skp_pool_ex_t *pool);
    void *mallocBlock(int size);
    void *mallocLarge(int size);
    bool checkAddr(const void *addr, int size);
    bool clearLarge();
    int checkAlign(skp_pool_align_head_t *align);
    bool checkLarge(skp_pool_large_ex_t *lare);

private:
    skp_pool_ex_t *m_pool;
};



#endif // SKPMALLOCPOOLEX_H
