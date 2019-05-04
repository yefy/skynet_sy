#ifndef SKP_MYSQL_CONN_H
#define SKP_MYSQL_CONN_H

#include <mysql/mysql.h>
#include "skpUtility.h"
#include "skpMallocPoolEx.h"

namespace AF {
enum Mysql_Error {
    Mysql_Error_Success = 0,
    Mysql_Error_Connect,
    Mysql_Error_Ping,
    Mysql_Error_Stmt_Init,
    Mysql_Error_Stmt_Prepare,
    Mysql_Error_Result_Metadata,
    Mysql_Error_Fetch_Fields,
    Mysql_Error_Bind_Param,
    Mysql_Error_Execute,
    Mysql_Error_Bind_Result,
    Mysql_Error_Stmt_Fetch,
    Mysql_Error_Stmt_NO_DATA,
    Mysql_Error_Stmt_Next_Result,
    Mysql_Error_Stmt_Attr_Set,
    Mysql_Error_Stmt_Store_Result,
};
}

#define DATA_CACHE_MAX 1024

typedef struct SkpMysqlData_s SkpMysqlData_t;
struct SkpMysqlData_s {
    char *buffer;
    my_bool isNULL;
    char R;
    uint16 R2;
    uint64 bufferLen;
    uint64 dataLenMax;
    uint64 dataLen;
    uint R3;
    enum enum_field_types type;
    char data[DATA_CACHE_MAX];
};

typedef struct SkpMysqlResultData_s SkpMysqlResultData_t;
struct SkpMysqlResultData_s {
    SkpMysqlData_t *data;
    int numberMysqlDataReal;
    int numberMysqlData;
    int currMysqlData;
};

typedef struct SkpMysqlResult_s SkpMysqlResult_t;
struct SkpMysqlResult_s {
    MYSQL_RES *resultMetadata;
    MYSQL_FIELD *fields;
    int numFields;
    int numberField;

    MYSQL_BIND *bind;
    int numberBind;
    SkpMysqlData_t *data;
    int m_numberData;

    std::vector<SkpMysqlResultData_t *> resultData;
    int numberResultDataReal;
    int numberResultData;
    int currResultData;
    SkpMysqlResultData_t *currMysqlResultData;
};


class SkpMysqlConn
{
public:
    SkpMysqlConn();
    ~SkpMysqlConn();
    AF::Mysql_Error skp_connect(const char *server, const char *user, const char *password, const char *database);
    AF::Mysql_Error skp_prepare(const char *sql);
    AF::Mysql_Error skp_execute();
    bool skp_next();
    bool skp_call_next();
    bool skp_call_last();
    bool skp_db_next();

    AF::Mysql_Error skp_fields_data();
    void skp_check_bind(MYSQL_BIND **binds, int &numberBind, int number);
    void skp_check_mysql_data(SkpMysqlData_t **datas, int &numberMysqlData, int number);
    void skp_check_mysql_data(SkpMysqlData_t *data);
    void skp_copy_mysql_data(SkpMysqlData_t *des, SkpMysqlData_t *src);
    bool skp_is_more(int size);

    void skp_param_char(char ch);
    void skp_param_short(uint16 sh);
    void skp_param_int(uint in);
    void skp_param_large_int(uint64 largeInt);
    void skp_param_double(double d);
    void skp_param_buffer(const char *p, int size);
    void skp_param_null();

    char skp_field_char();
    uint16 skp_field_short();
    uint skp_field_int();
    uint64 skp_field_large_int();
    double skp_field_double();
    char *skp_field_buffer(int &size);

public:
    SkpMallocPoolEx *m_poolEx;
    MYSQL *m_mysql;
    MYSQL_STMT *m_stmt;

    int m_paramCount;
    int m_numberParam;
    MYSQL_BIND *m_bind;
    int m_numberBind;
    SkpMysqlData_t *m_data;
    int m_numberMysqlData;

    std::vector<SkpMysqlResult_t *> m_result;
    int m_numberResultReal;
    int m_numberResult;
    int m_currResult;
    SkpMysqlResult_t *m_currMysqlResult;
};

#endif // SKP_MYSQL_CONN_H
