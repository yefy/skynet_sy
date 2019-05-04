#include "skpUtility.h"

#define SYS_TIME_RESOLUTION_US 300*1000

static int64 g_skp_system_time_us_cache = 0;
static int64 g_skp_system_time_startup_time = 0;
static struct timeval g_skp_system_time_tv_cache = {0,0};

int64 skp_get_system_time_ms()
{
    if (g_skp_system_time_us_cache <= 0) {
        skp_update_system_time_ms(skp_true);
    }

    return g_skp_system_time_us_cache / 1000;
}

int64 skp_get_system_time_ms_ex()
{
    skp_update_system_time_ms(skp_true);
    return g_skp_system_time_us_cache;
}

struct timeval *skp_get_system_time_tv()
{
    return &g_skp_system_time_tv_cache;
}

int64 skp_get_system_startup_time_ms()
{
    if (g_skp_system_time_startup_time <= 0) {
        skp_update_system_time_ms(skp_true);
    }

    return g_skp_system_time_startup_time / 1000;
}



int64 skp_update_system_time_ms(bool isGetTime)
{
    if(isGetTime) {
        if (gettimeofday(&g_skp_system_time_tv_cache, NULL) < 0) {
            printf("gettimeofday failed, ignore\n");
            return -1;
        }
    }

    // we must convert the tv_sec/tv_usec to int64_t.
    int64 now_us = ((int64)g_skp_system_time_tv_cache.tv_sec) * 1000 * 1000 + (int64)g_skp_system_time_tv_cache.tv_usec;

    // for some ARM os, the starttime maybe invalid,
    // for example, on the cubieboard2, the srs_startup_time is 1262304014640,
    // while now is 1403842979210 in ms, diff is 141538964570 ms, 1638 days
    // it's impossible, and maybe the problem of startup time is invalid.
    // use date +%s to get system time is 1403844851.
    // so we use relative time.
    if (g_skp_system_time_us_cache <= 0) {
        g_skp_system_time_us_cache = now_us;
        g_skp_system_time_startup_time = now_us;
        return g_skp_system_time_us_cache / 1000;
    }

    // use relative time.
    int64_t diff = now_us - g_skp_system_time_us_cache;
    diff = skp_max(0, diff);
    if (diff < 0 || diff > 1000 * SYS_TIME_RESOLUTION_US) {
        printf("system time jump, history=%lld us, now=%lld us, diff=%lld us\n",
                    g_skp_system_time_us_cache, now_us, diff);
        g_skp_system_time_startup_time += diff;
    }

    g_skp_system_time_us_cache = now_us;
    printf("system time updated, startup=%lld us, now=%lld us\n",
              g_skp_system_time_startup_time, g_skp_system_time_us_cache);

    return g_skp_system_time_us_cache / 1000;
}

struct timeval skp_gettimeofday()
{
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return tv;
}

int64 skp_diff_time(struct timeval &tv)
{
    int64 t1 = tv.tv_sec * 1000 + tv.tv_usec / 1000;
    struct timeval tv2;
    gettimeofday(&tv2, NULL);
    int64 t2 = tv2.tv_sec * 1000 + tv2.tv_usec / 1000;
    return t2 - t1;
}

std::string skp_itos(int64 number)
{
    char buffer[1024];
    int size = sprintf(buffer, "%lld", number);
    return std::string(buffer, size);
}

int64 skp_stoi(char *str, int size)
{
    char buffer[1024];
    memset(buffer, 0x00, sizeof(buffer));
    memcpy(buffer, str, size);
    printf("buffer = %s \n", buffer);
    int64 number = 0;
    sscanf(buffer, "%lld", &number);
    return number;
}


bool setNoblock(int fd)
{
    int flags;
    if ((flags = fcntl(fd, F_GETFL, 0)) < 0 ||
            fcntl(fd, F_SETFL, flags | O_NONBLOCK) < 0) {
        SKP_ASSERT(skp_false);
        return skp_false;
    }
    return skp_true;
}

bool setBlock(int fd)
{
    // 设为阻塞模式
    int flags;
    if ((flags = fcntl(fd, F_GETFL, 0)) < 0 ||
            fcntl(fd, F_SETFL, flags & ~O_NONBLOCK) < 0) {
        SKP_ASSERT(skp_false);
        return skp_false;
    }
    return skp_true;
}



SkpStringSplit::SkpStringSplit(const char *buffer, const char *split):
    m_start(buffer),
    m_end(buffer + strlen(buffer)),
    m_split(split),
    m_splitSize(strlen(split)),
    m_curr(buffer),
    m_isEnd(false)
{

}

bool SkpStringSplit::hasNext(const char *&s, int &size)
{
    if(m_isEnd == true)
        return false;

    if(m_curr == m_end)
    {
        s = m_curr;
        size = 0;
        m_isEnd = true;
        return true;
    }

    s = m_curr;
    const char *p = strstr(m_curr, m_split);
    if(p)
    {
        m_curr = p + m_splitSize;
        size = p - s;
        return true;
    }

    m_isEnd = true;
    m_curr = m_end;
    size = m_end - s;
    return true;
}


const char *find_index(const char *str, const char **tableStr, int &data)
{
    printf("find_index str = %s \n", str);
    const char *s = NULL;
    for(int i = 0;  ; ++i)
    {
        s = tableStr[i];
        if(!s)
            break;

        printf("find_index tableStr = %s \n", s);
        if(strcasecmp(s, str) == 0)
        {
            data = i;
            printf("find_index data = %d \n",data);
            return s;
        }
    }

    return NULL;
}

const char *find_data(const char *str, const char **tableStr, const int *tableData, int &data)
{
    printf("find_data str = %s \n", str);
    const char *s = NULL;
    for(int i = 0;  ; ++i)
    {
        s = tableStr[i];
        if(!s)
            break;

        printf("find_data tableStr = %s \n", s);
        if(strcasecmp(s, str) == 0)
        {
            data = tableData[i];
            printf("find_data data = %d \n",data);
            return s;
        }
    }

    return NULL;
}


int64 split_toInt64(const char *str, const char *split, const char **tableStr, const int *tableData)
{
    int64 data = 0;
    SkpStringSplit cSkpStringSplit(str, split);
    const char *s = NULL;
    int size = 0;
    while(cSkpStringSplit.hasNext(s, size))
    {
        char buffer[512] = "";
        memcpy(buffer, s, size);
        int d = 0;
        if(find_data(buffer, tableStr, tableData, d))
        {
            data |= d;
        }
    }

    return data;
}
