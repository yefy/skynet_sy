#ifndef SKPAUTOFREE_H
#define SKPAUTOFREE_H

#include "skpUtility.h"


#define skp_delete(p) \
    if(p) { \
        delete (p); \
        (p) =  skp_null; \
    }

#define skp_delete_array(p) \
    if(p) { \
        delete[] (p); \
        (p) = skp_null; \
    }


template<class T>
class SkpAutoDelete
{
public:
    SkpAutoDelete(T** ptr, bool isArray) {
        m_ptr = ptr;
        m_isArray = isArray;
    }

    virtual ~SkpAutoDelete() {
        if(skp_null == m_ptr || skp_null == *m_ptr) {
            return;
        }

        if(m_isArray)
        {
            skp_delete_array(*m_ptr);
        }
        else
        {
            skp_delete(*m_ptr);
        }
    }

private:
    T** m_ptr;
    bool m_isArray;
};


#define __SkpAutoDelete(className, instance) \
        SkpAutoDelete<className> autoDelete##Instance(&instance, skp_false); \
        SKP_UNUSED(autoDelete##Instance)

#define __SkpAutoDeleteArray(className, instance) \
        SkpAutoDelete<className> autoDelete##Instance(&instance, skp_true); \
        SKP_UNUSED(autoDelete##Instance)

#endif // SKPAUTOFREE_H
