#ifndef SKP_PUBLIC_UTILITY_H
#define SKP_PUBLIC_UTILITY_H

#include <stdint.h>

#define skp_min(a, b) (((a) < (b))? (a) : (b))
#define skp_max(a, b) (((a) < (b))? (b) : (a))

/*  signed  */
typedef bool            int1;
typedef char		int8;
typedef short int		int16;
typedef int			int32;
typedef long int	longptr;
typedef long long int		int64;

/*  unsigned    */
typedef unsigned char		uint8;
typedef unsigned short int	uint16;
typedef unsigned int		uint32;
typedef unsigned long long int	uint64;

typedef unsigned int		uintptr;
typedef unsigned long int		ulongptr;

typedef unsigned char		uchar;
typedef unsigned short int	uint16;
typedef unsigned int		uint;
typedef unsigned long int		ulong;
typedef unsigned long long int	uint64;





//#  define __INT64_C(c)	c ## LL
//#  define __UINT64_C(c)	c ## ULL

//# define INT8_MIN		(-128)
//# define INT16_MIN		(-32767-1)
//# define INT32_MIN		(-2147483647-1)
//# define INT64_MIN		(-__INT64_C(9223372036854775807)-1)
//// Maximum of signed integral types.
//# define INT8_MAX		(127)
//# define INT16_MAX		(32767)
//# define INT32_MAX		(2147483647)
//# define INT64_MAX		(__INT64_C(9223372036854775807))

//// Maximum of unsigned integral types.
//# define UINT8_MAX		(255)
//# define UINT16_MAX		(65535)
//# define UINT32_MAX		(4294967295U)
//# define UINT64_MAX		(__UINT64_C(18446744073709551615))


#define skp_true    true
#define skp_false   false

#define skp_null    nullptr

#define SKP_TRUE    true
#define SKP_FALSE   false

#define SKP_NULL    NULL

#define SKP_OK      true
#define SKP_ERROR   false

#define SKP_SUCCESS 0
#define SKP_FAILED  -1


#define SKP_UNUSED(x) (void)x;

#define SKP_ASSERT(x)   assert(x);

#define skp_align(d, a)     (((d) + (a - 1)) & ~(a - 1))
#define skp_align_ptr(p, a) \
    (uchar *) (((ulongptr) (p) + ((ulongptr) a - 1)) & ~((ulongptr) a - 1))

#endif // SKP_PUBLIC_UTILITY_H
