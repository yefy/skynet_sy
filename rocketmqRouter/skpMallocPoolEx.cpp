#include "skpMallocPoolEx.h"
#include "skpMalloc.h"
/*
 * NGX_MAX_ALLOC_FROM_POOL should be (ngx_pagesize - 1), i.e. 4095 on x86.
 * On Windows NT it decreases a number of locked pages in a kernel.
 */

#define skp_pagesize_ex 4 * 1024

#define SKP_MAX_ALLOC_FROM_POOL_EX  (skp_pagesize - 1)

#define SKP_DEFAULT_POOL_SIZE_EX    (16 * 1024)
#define SKP_ALIGN_TYPE  unsigned long long
#define SKP_ALIGNMENT_EX   sizeof(SKP_ALIGN_TYPE)
#define SKP_POOL_ALIGNMENT_EX       16
#define SKP_MIN_POOL_SIZE_EX                                                     \
    skp_align((sizeof(skp_pool_ex_t) + 2 * sizeof(skp_pool_large_ex_t)),            \
              SKP_POOL_ALIGNMENT_EX)

#define SKP_ALIGN_SIZE_EX(size) (((size) + sizeof(skp_pool_align_head_t) - 1)  / sizeof(skp_pool_align_head_t))
#define SKP_ALIGN_MALLOC_SIZE_EX(size) (SKP_ALIGN_SIZE_EX(size) + 1)
#define SKP_SIZE_EX(size) ((SKP_ALIGN_SIZE_EX(size)) * sizeof(skp_pool_align_head_t))
#define SKP_MALLOC_SIZE_EX(size) ((SKP_ALIGN_SIZE_EX(size) + 1) * sizeof(skp_pool_align_head_t))

#define SKP_ALIGN_HEAD_EX sizeof(skp_pool_align_head_t)
#define SKP_ALIGN_LARGE_HEAD_EX skp_max((skp_align(sizeof(skp_pool_large_ex_t),SKP_ALIGNMENT_EX)), SKP_ALIGN_HEAD_EX)

#define SKP_POOL_FLAG 0xAABBCCDD
#define SKP_LARGE_POOL_FLAG 0xDDCCBBAA

#define SKP_POOL_CACHE_MAX 1024 * 64

typedef struct skp_pool_align_head_s skp_pool_align_head_t;
struct skp_pool_align_head_s {
    union {
        struct {
            uint flag;
            uint isFree:1;
            uint alignSize:31;
            uint64 size;
            QUEUE_NODE(skp_pool_align_head_t) freeChain;
            QUEUE_NODE(skp_pool_align_head_t) mallocChain;
            QUEUE_NODE(skp_pool_align_head_t) chain;
        };
        SKP_ALIGN_TYPE align;
    };
};

typedef struct skp_pool_large_ex_s skp_pool_large_ex_t;
struct skp_pool_large_ex_s {
    union {
        struct {
            uint flag;
            uint size;
            QUEUE_NODE(skp_pool_large_ex_t) chain;
        };
        SKP_ALIGN_TYPE align;
    };
};

typedef QUEUE_HEAD(skp_pool_list_align_head_s, skp_pool_align_head_t) skp_pool_list_align_head_t;

typedef struct skp_pool_data_ex_s{
    uchar *first;
    uchar *end;
    skp_pool_align_head_t *head;
    struct skp_pool_ex_s *next;
    skp_pool_list_align_head_t freeHead;
    skp_pool_list_align_head_t mallocHead;
    skp_pool_list_align_head_t listcHead;
}skp_pool_data_ex_t;

typedef QUEUE_HEAD(skp_pool_list_large_ex_s, skp_pool_large_ex_t) skp_pool_list_large_ex_t;

typedef struct skp_pool_ex_s skp_pool_ex_t;
struct skp_pool_ex_s {
    skp_pool_data_ex_t       d;
    struct skp_pool_ex_s           *last;
    int R;
    skp_pool_list_large_ex_t largeHead;
    int                alignMax;
    uint64           totleSize;
};


SkpMallocPoolEx::SkpMallocPoolEx(int size)
{
    int max = (size > skp_pagesize_ex)? size:skp_pagesize_ex;
    m_pool = create(max);

}

SkpMallocPoolEx::~SkpMallocPoolEx()
{
    destroy();
}


skp_pool_ex_t *SkpMallocPoolEx::create(int size)
{
    int alignSize = skp_align(size, SKP_POOL_ALIGNMENT_EX);

    skp_pool_ex_t  *p = (skp_pool_ex_t  *)skp_memalign(SKP_POOL_ALIGNMENT_EX, alignSize);
    SKP_ASSERT(p);
    if (p == NULL) {
        return NULL;
    }

    p->d.first = (uchar *)p;
    p->d.end = (uchar *) p + alignSize;

    uchar *head = skp_align_ptr((uchar *) p + sizeof(skp_pool_ex_t), SKP_ALIGNMENT_EX);
    p->d.head = (skp_pool_align_head_t *)head;
    p->d.head->flag = SKP_POOL_FLAG;
    p->d.head->isFree = skp_true;
    p->d.head->alignSize = (SKP_ALIGN_SIZE_EX((uchar *)p->d.end - head)) - 1;
    p->d.head->size = p->d.head->alignSize * SKP_ALIGN_HEAD_EX;
    QUEUE_NODE_INIT(p->d.head, freeChain);
    QUEUE_NODE_INIT(p->d.head, mallocChain);
    QUEUE_NODE_INIT(p->d.head, chain);

    QUEUE_INIT(&p->d.freeHead);
    QUEUE_INIT(&p->d.mallocHead);
    QUEUE_INIT(&p->d.listcHead);

    QUEUE_INSETT_LAST(&p->d.freeHead, p->d.head, freeChain);
    QUEUE_INSETT_LAST(&p->d.listcHead, p->d.head, chain);

    p->d.next = NULL;

    p->last = p;
    QUEUE_INIT(&p->largeHead);
    p->alignMax = p->d.head->alignSize;

    p->totleSize = alignSize;

    return p;
}

bool SkpMallocPoolEx::clearLarge()
{
    skp_pool_list_large_ex_t *largeHead = (&m_pool->largeHead);
    while(!QUEUE_EMPTY(largeHead)) {
        skp_pool_large_ex_t *first = largeHead->first;

        if(checkLarge(first) == skp_false) {
            return skp_false;
        }

        QUEUE_REMOVE(largeHead, first, chain);

        first->flag = 0;
        m_pool->totleSize -= first->size + SKP_ALIGN_LARGE_HEAD_EX;

        skp_free(first);
    }

    return skp_true;
}

void SkpMallocPoolEx::destroy()
{
    if(clearLarge() == skp_false) {
        SKP_ASSERT(skp_false);
    }

    skp_pool_ex_t          *p, *n;
    for (p = m_pool, n = m_pool->d.next; /* void */; p = n, n = n->d.next) {

        skp_free(p);
        if (n == NULL) {
            break;
        }
    }
}


void SkpMallocPoolEx::reset()
{
    if(clearLarge() == skp_false) {
        SKP_ASSERT(skp_false);
    }

    skp_pool_ex_t  *p = m_pool;
    while(p) {

        p->d.head->flag = SKP_POOL_FLAG;
        p->d.head->isFree = skp_true;
        p->d.head->alignSize = (SKP_ALIGN_SIZE_EX((uchar *)p->d.end - (uchar *)p->d.head)) - 1;
        p->d.head->size = p->d.head->alignSize * SKP_ALIGN_HEAD_EX;
        QUEUE_NODE_INIT(p->d.head, freeChain);
        QUEUE_NODE_INIT(p->d.head, mallocChain);
        QUEUE_NODE_INIT(p->d.head, chain);

        QUEUE_INIT(&p->d.freeHead);
        QUEUE_INIT(&p->d.mallocHead);
        QUEUE_INIT(&p->d.listcHead);

        QUEUE_INSETT_LAST(&p->d.freeHead, p->d.head, freeChain);
        QUEUE_INSETT_LAST(&p->d.listcHead, p->d.head, chain);

        p = p->d.next;
    }
}


void *SkpMallocPoolEx::malloc(const char *file, uint16 line, const char *function, int mallocSize)
{
    SKP_UNUSED(file);
    SKP_UNUSED(line);
    SKP_UNUSED(function);
    void *p = doMalloc(mallocSize, m_pool);
    if(!p)
        p = mallocLarge(mallocSize);

    return p;
}

void *SkpMallocPoolEx::doMalloc(int mallocSize, skp_pool_ex_t *pool)
{
    int alignSize = SKP_ALIGN_MALLOC_SIZE_EX(mallocSize);

    if (alignSize <= m_pool->alignMax) {
        skp_pool_ex_t  *p = pool;
        while(p) {
            skp_pool_align_head_t *head = p->d.freeHead.first;

            while(head) {
                if(checkAlign(head) == skp_false) {
                    SKP_ASSERT(skp_false);
                }

                if(!head->isFree) {
                    SKP_ASSERT(skp_false);
                }

                if(head->alignSize >= alignSize) {
                    QUEUE_REMOVE(&p->d.freeHead, head, freeChain);

                    head->alignSize -= alignSize;

                    skp_pool_align_head_t *alignHead = head;
                    alignHead += head->alignSize;
                    alignHead->flag = SKP_POOL_FLAG;
                    alignHead->isFree = skp_false;
                    alignHead->alignSize = alignSize;
                    alignHead->size = mallocSize;

                    QUEUE_INSETT_LAST(&p->d.mallocHead, alignHead, mallocChain);

                    if(alignHead != head) {
                        QUEUE_INSETT_LAST(&p->d.freeHead, head, freeChain);
                        QUEUE_INSETT_NODE(&p->d.listcHead, head, alignHead, chain);
                    }

                    return alignHead + 1;
                }

                head = head->freeChain.next;
            }

            p = p->d.next;

        }

        return mallocBlock(mallocSize);
    }

    return NULL;
}

void *SkpMallocPoolEx::mallocBlock(int mallocSize)
{
    int size = (int) (m_pool->d.end - m_pool->d.first);

    int alignSize = skp_align(size, SKP_POOL_ALIGNMENT_EX);

    skp_pool_ex_t  *p = (skp_pool_ex_t  *)skp_memalign(SKP_POOL_ALIGNMENT_EX, alignSize);
    SKP_ASSERT(p);
    if (p == NULL) {
        return NULL;
    }

    p->d.first = (uchar *)p;
    p->d.end = (uchar *) p + alignSize;

    uchar *head = skp_align_ptr((uchar *) p + sizeof(skp_pool_data_ex_t), SKP_ALIGNMENT_EX);
    p->d.head = (skp_pool_align_head_t *)head;
    p->d.head->flag = SKP_POOL_FLAG;
    p->d.head->isFree = skp_true;
    p->d.head->alignSize = (SKP_ALIGN_SIZE_EX((uchar *)p->d.end - head)) - 1;
    p->d.head->size = p->d.head->alignSize * sizeof(skp_pool_align_head_t);
    QUEUE_NODE_INIT(p->d.head, freeChain);
    QUEUE_NODE_INIT(p->d.head, mallocChain);
    QUEUE_NODE_INIT(p->d.head, chain);

    QUEUE_INIT(&p->d.freeHead);
    QUEUE_INIT(&p->d.mallocHead);
    QUEUE_INIT(&p->d.listcHead);

    QUEUE_INSETT_LAST(&p->d.freeHead, p->d.head, freeChain);
    QUEUE_INSETT_LAST(&p->d.listcHead, p->d.head, chain);

    p->d.next = NULL;

    m_pool->last->d.next = p;
    m_pool->last = p;
    m_pool->totleSize += alignSize;

    return doMalloc(mallocSize, p);

}


void *SkpMallocPoolEx::mallocLarge(int mallocSize)
{
    int alignSize = mallocSize + SKP_ALIGN_LARGE_HEAD_EX;

    skp_pool_large_ex_t  *p = (skp_pool_large_ex_t  *)skp_malloc(alignSize);
    SKP_ASSERT(p);
    if (p == NULL) {
        return NULL;
    }

    m_pool->totleSize += alignSize;



    p->flag = SKP_LARGE_POOL_FLAG;
    p->size = mallocSize;

    QUEUE_INSETT_LAST(&m_pool->largeHead, p, chain);

    return (uchar *)p + SKP_ALIGN_LARGE_HEAD_EX;
}


bool SkpMallocPoolEx::free(const char *file, uint16 line, const char *function, void *p)
{
    SKP_UNUSED(file);
    SKP_UNUSED(line);
    SKP_UNUSED(function);

    if(!p) {
        return skp_false;
    }


    skp_pool_large_ex_t *largeNode = (skp_pool_large_ex_t *)((ulong)p - SKP_ALIGN_LARGE_HEAD_EX);
    if(largeNode->flag == SKP_LARGE_POOL_FLAG) {

    QUEUE_REMOVE(&m_pool->largeHead,largeNode, chain);
    largeNode->flag = 0;

    m_pool->totleSize -= largeNode->size + SKP_ALIGN_LARGE_HEAD_EX;

    skp_free(largeNode);

    return skp_true;
    }



    skp_pool_align_head_t *node = (skp_pool_align_head_t *)((ulong)p - SKP_ALIGN_HEAD_EX);

    if(node->flag == SKP_POOL_FLAG) {
        if(node->isFree) {
            return skp_false;
        }
        skp_pool_ex_t  *m = m_pool;

        while(m) {
            if ((uchar *)node > m->d.first && (uchar *)node < m->d.end) {

                QUEUE_REMOVE(&m->d.mallocHead, node, mallocChain);
                QUEUE_INSETT_LAST(&m->d.freeHead, node, freeChain);
                node->isFree = skp_true;

                skp_pool_align_head_t *prev = node->chain.prev;
                skp_pool_align_head_t *next = node->chain.next;
                if(prev) {
                    if(checkAlign(prev) == skp_false) {
                        return  skp_false;
                    }
                }
                if(next) {
                    if(checkAlign(next) == skp_false) {
                        return  skp_false;
                    }
                }

                if(next && next->isFree) {
                    if((uchar *)(node + node->alignSize) == (uchar *)next) {
                        QUEUE_REMOVE(&m->d.freeHead, next, freeChain);
                        QUEUE_REMOVE(&m->d.listcHead, next, chain);

                        node->alignSize += next->alignSize;
                        node->size = node->alignSize * SKP_ALIGN_HEAD_EX;

                        memset(next, 0x00, SKP_ALIGN_HEAD_EX);
                    }
                }

                if(prev && prev->isFree) {
                    if((uchar *)(prev + prev->alignSize) == (uchar *)node) {
                        QUEUE_REMOVE(&m->d.freeHead, node, freeChain);
                        QUEUE_REMOVE(&m->d.listcHead, node, chain);

                        prev->alignSize += node->alignSize;
                        prev->size = prev->alignSize * SKP_ALIGN_HEAD_EX;

                        memset(node, 0x00, SKP_ALIGN_HEAD_EX);
                    }
                }

                return skp_true;

            }

            m = m->d.next;
        }

        return skp_false;
    }

    return skp_true;
}


void *
SkpMallocPoolEx::calloc(const char *file, uint16 line, const char *function, int size)
{
    void *p;

    p = malloc(file, line, function, size);
    if (p) {
        skp_memzero(p, size);
    }

    return p;
}

int  SkpMallocPoolEx::size()
{
    return m_pool->totleSize;
}

bool SkpMallocPoolEx::checkAddr(const void *addr, int size)
{
    bool isError = skp_false;
    skp_pool_ex_t  *m = m_pool;
    while(m) {
        if ((uchar *)addr > m->d.first && (uchar *)addr < m->d.end) {
            if(QUEUE_EMPTY(&m->d.mallocHead)) {
                isError = skp_true;
                goto __End;
            }

            skp_pool_align_head_t *node = m->d.mallocHead.first;

            while(node) {
                if(checkAlign(node) == skp_false) {
                    return  skp_false;
                }

                void *start = (char *)(node + 1);
                void *end = (char *)start + node->size;
                if(addr >= start && addr <= end) {
                    void *addEnd = (char *)addr + size;
                    if(addEnd > end || addEnd < start)
                        isError = skp_true;

                    goto __End;
                }

                node = node->mallocChain.next;
            }

            isError = skp_true;
            goto __End;
        }

        m = m->d.next;

    }

    do {
        skp_pool_large_ex_t *largeNode = m_pool->largeHead.first;
        while(largeNode) {
            if(checkLarge(largeNode) == skp_false) {
                return  skp_false;
            }

            void *start = (uchar *)largeNode + SKP_ALIGN_LARGE_HEAD_EX;
            void *end = (char *)start + largeNode->size;

            if(addr >= start && addr <= end) {
                void *addEnd = (char *)addr + size;
                if(addEnd > end || addEnd < start)
                    isError = skp_true;

                goto __End;
            }

            largeNode = largeNode->chain.next;
        }
    } while(0);



__End:
    if(isError) {
        return skp_false;
    }
    return skp_true;
}

bool SkpMallocPoolEx::write(void *dest, const void *src, int size)
{
    bool ret = checkAddr(dest, size);
    if(ret == skp_true) {
        ::memcpy(dest, src, size);
    }

    return ret;
}

int SkpMallocPoolEx::read(const void *src, void *dest, int size)
{
    bool ret = checkAddr(src, size);
    if(ret == skp_true) {
        ::memcpy(dest, src, size);
    }

    return ret;
}

bool SkpMallocPoolEx::memset(void *dest, int data, int size)
{
    int ret = checkAddr(dest, size);
    if(ret == skp_true) {
        ::memset(dest, data, size);
    }

    return ret;
}

int SkpMallocPoolEx::checkAlign(skp_pool_align_head_t *align)
{
    if(!align || align->flag != SKP_POOL_FLAG) {
        return skp_false;
    }
    return skp_true;
}

bool SkpMallocPoolEx::checkLarge(skp_pool_large_ex_t *lare)
{
    if(!lare || lare->flag != SKP_LARGE_POOL_FLAG) {
        return skp_false;
    }
    return skp_true;
}
