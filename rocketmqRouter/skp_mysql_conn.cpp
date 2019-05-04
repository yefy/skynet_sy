#include "skp_mysql_conn.h"
#include "skpAutoFree.h"

SkpMysqlConn::SkpMysqlConn() :
    m_stmt(NULL),
    m_paramCount(0),
    m_numberParam(0),
    m_bind(NULL),
    m_numberBind(0),
    m_data(NULL),
    m_numberMysqlData(0),
    m_numberResult(0)
{
    m_poolEx = new SkpMallocPoolEx();
    m_mysql = mysql_init(NULL);
}

SkpMysqlConn::~SkpMysqlConn()
{
    skp_delete(m_poolEx);
    mysql_stmt_close(m_stmt);
    mysql_close(m_mysql);
}

AF::Mysql_Error SkpMysqlConn::skp_connect(const char *server, const char *user, const char *password, const char *database)
{
    if (!mysql_real_connect(m_mysql, server, user, password, database, 0, NULL, CLIENT_MULTI_RESULTS)) {
        printf("mysql_real_connect error = %s, errno = %d \n",
               mysql_error(m_mysql), mysql_errno(m_mysql));
        return AF::Mysql_Error_Connect;
    }

    if(mysql_ping(m_mysql) != 0) {
        printf("mysql_ping error = %s, errno = %d \n",
               mysql_error(m_mysql), mysql_errno(m_mysql));
        return AF::Mysql_Error_Ping;
    }


    mysql_set_character_set(m_mysql, "utf8");    //gbk  utf8

    m_stmt = mysql_stmt_init(m_mysql);
    if (!m_stmt) {
        printf("mysql_stmt_init error \n");
        return AF::Mysql_Error_Stmt_Init;
    }

    return AF::Mysql_Error_Success;
}

AF::Mysql_Error SkpMysqlConn::skp_prepare(const char *sql)
{
    if(mysql_stmt_prepare(m_stmt, sql, strlen(sql))) {
        printf("mysql_stmt_prepare error = %s, errno = %d \n",
               mysql_stmt_error(m_stmt), mysql_stmt_errno(m_stmt));
        return AF::Mysql_Error_Stmt_Prepare;
    }

    m_paramCount = mysql_stmt_param_count(m_stmt);

    if(m_paramCount > 0) {
        skp_check_bind(&m_bind, m_numberBind, m_paramCount);
        skp_check_mysql_data(&m_data, m_numberMysqlData, m_paramCount);
    }

    m_numberParam = 0;
    return AF::Mysql_Error_Success;
}

AF::Mysql_Error SkpMysqlConn::skp_execute()
{
    SKP_ASSERT(m_numberParam == m_paramCount);
    if(m_paramCount > 0) {
        if(mysql_stmt_bind_param(m_stmt, m_bind)) {
            printf("mysql_stmt_bind_param error = %s, errno = %d \n",
                   mysql_stmt_error(m_stmt), mysql_stmt_errno(m_stmt));
            return AF::Mysql_Error_Bind_Param;
        }
    }


    if(mysql_stmt_execute(m_stmt)) {
        printf("mysql_stmt_execute error = %s, errno = %d \n",
               mysql_stmt_error(m_stmt), mysql_stmt_errno(m_stmt));
        return AF::Mysql_Error_Execute;
    }

    return skp_fields_data();
}

bool SkpMysqlConn::skp_next()
{
    if(m_currMysqlResult->currResultData >= m_currMysqlResult->numberResultDataReal)
        return skp_false;
    m_currMysqlResult->currMysqlResultData = m_currMysqlResult->resultData.at(m_currMysqlResult->currResultData);
    m_currMysqlResult->currMysqlResultData->currMysqlData = 0;
    m_currMysqlResult->currResultData++;
    return skp_true;
}

bool SkpMysqlConn::skp_call_next()
{
    if(m_currResult >= (m_numberResultReal - 1))
        return skp_false;

    m_currMysqlResult = m_result.at(m_currResult);
    m_currMysqlResult->currResultData = 0;
    m_currResult++;
    return skp_true;
}

bool SkpMysqlConn::skp_call_last()
{
    if(m_numberResultReal <= 0)
        return skp_false;

    int currResult = m_numberResultReal - 1;
    m_currMysqlResult = m_result.at(currResult);
    m_currMysqlResult->currResultData = 0;

    return skp_true;
}

bool SkpMysqlConn::skp_db_next()
{
    if(m_currResult >= (m_numberResultReal))
        return skp_false;

    m_currMysqlResult = m_result.at(m_currResult);
    m_currMysqlResult->currResultData = 0;
    m_currResult++;
    return skp_true;
}

AF::Mysql_Error SkpMysqlConn::skp_fields_data()
{
    my_bool isMaxLen = 1;
    if (mysql_stmt_attr_set(m_stmt, STMT_ATTR_UPDATE_MAX_LENGTH, &isMaxLen)) {
        return AF::Mysql_Error_Stmt_Attr_Set;
    }

    int status;
    m_numberResultReal = 0;
    do {
        int numFields = mysql_stmt_field_count(m_stmt);

        if(numFields > 0) {

            if (mysql_stmt_store_result(m_stmt)) {
                return AF::Mysql_Error_Stmt_Store_Result;
            }

            if(m_numberResultReal >= m_numberResult) {
                SkpMysqlResult_t *result = (SkpMysqlResult_t *)skp_pool_calloc(m_poolEx, sizeof(SkpMysqlResult_t));
                m_result.push_back(result);
                m_numberResult++;
            }
            SkpMysqlResult_t *result = m_result.at(m_numberResultReal);
            result->numFields = numFields;
            m_numberResultReal++;


            result->resultMetadata = mysql_stmt_result_metadata(m_stmt);
            if (result->resultMetadata == NULL)
            {
                printf("mysql_stmt_result_metadata error = %s, errno = %d \n",
                       mysql_stmt_error(m_stmt), mysql_stmt_errno(m_stmt));
                return AF::Mysql_Error_Result_Metadata;
            }

            result->fields = mysql_fetch_fields(result->resultMetadata);
            if (result->fields == NULL){
                printf("mysql_fetch_fields error = %s, errno = %d \n",
                       mysql_stmt_error(m_stmt), mysql_stmt_errno(m_stmt));
                return AF::Mysql_Error_Fetch_Fields;
            }

            skp_check_bind(&result->bind, result->numberBind, result->numFields);
            skp_check_mysql_data(&result->data, result->m_numberData, result->numFields);

            for (int i = 0; i < result->numFields; i++)
            {
                MYSQL_FIELD *field = &result->fields[i];

                SkpMysqlData_t *data = &result->data[i];
                data->isNULL = 0;
                data->type = field->type;
                data->dataLen = 0;
                data->dataLenMax = field->max_length;
                if(skp_is_more(data->dataLenMax)) {
                    skp_check_mysql_data(data);
                }

                MYSQL_BIND *bind = &result->bind[i];
                bind->buffer_type = data->type;
                if(!skp_is_more(data->dataLenMax)) {
                    bind->buffer = data->data;
                    bind->buffer_length = DATA_CACHE_MAX;
                } else {
                    bind->buffer = data->buffer;
                    bind->buffer_length = data->bufferLen;
                }

                bind->length = (unsigned long *)&data->dataLen;
                bind->is_null = &data->isNULL;
            }

            if(mysql_stmt_bind_result(m_stmt, result->bind)){
                printf("mysql_stmt_bind_result error = %s, errno = %d \n",
                       mysql_stmt_error(m_stmt), mysql_stmt_errno(m_stmt));
                return AF::Mysql_Error_Bind_Result;
            }

            int res = 1;
            result->numberResultDataReal = 0;
            do {
                res = mysql_stmt_fetch(m_stmt);

                if(res == 0) {
                    if(result->numberResultDataReal >= result->numberResultData) {
                        SkpMysqlResultData_t *resultData = (SkpMysqlResultData_t *)skp_pool_calloc(m_poolEx, sizeof(SkpMysqlResultData_t));
                        result->resultData.push_back(resultData);
                        result->numberResultData++;
                    }
                    SkpMysqlResultData_t *resultData = result->resultData.at(result->numberResultDataReal);
                    resultData->numberMysqlDataReal = result->numFields;
                    result->numberResultDataReal++;

                    skp_check_mysql_data(&resultData->data, resultData->numberMysqlData, result->numFields);

                    for (int i = 0; i < result->numFields; i++){
                        skp_copy_mysql_data(&resultData->data[i], &result->data[i]);
                    }
                }
                if(res == 1) {
                    printf("mysql_stmt_fetch error = %s, errno = %d \n",
                           mysql_stmt_error(m_stmt), mysql_stmt_errno(m_stmt));
                    return AF::Mysql_Error_Stmt_Fetch;
                }

                if(res == MYSQL_NO_DATA) {
                }

            }while(res == 0);
            mysql_free_result(result->resultMetadata);
            //m_poolEx->SKP_PFREE(result->bind);
            //SKP_PFREE(m_poolEx, result->bind);
        }

        status = mysql_stmt_next_result(m_stmt);
//        if(status) {
//            printf("mysql_stmt_next_result error = %s, errno = %d \n",
//                   mysql_stmt_error(m_stmt), mysql_stmt_errno(m_stmt));
//            return AF::Mysql_Error_Stmt_Next_Result;
//        }
    }while(status == 0);


    m_currResult = 0;

    return AF::Mysql_Error_Success;
}

void SkpMysqlConn::skp_check_bind(MYSQL_BIND **binds, int &numberBind, int number)
{
    if(*binds == NULL) {
        numberBind = number;
        *binds = (MYSQL_BIND *)skp_pool_calloc(m_poolEx, sizeof(MYSQL_BIND) * numberBind);
    } else {
        if(numberBind < number) {
            //m_poolEx->SKP_PFREE(*binds);
            skp_pool_free(m_poolEx, *binds);
            numberBind = number;
            *binds = (MYSQL_BIND *)skp_pool_calloc(m_poolEx, sizeof(MYSQL_BIND) * numberBind);
        } else {
            m_poolEx->memset(*binds, 0x00, sizeof(MYSQL_BIND) * numberBind);
        }
    }
}

void SkpMysqlConn::skp_check_mysql_data(SkpMysqlData_t **datas, int &numberMysqlData, int number)
{
    if(*datas == NULL) {
        numberMysqlData = number;
        *datas = (SkpMysqlData_t *)skp_pool_calloc(m_poolEx, sizeof(SkpMysqlData_t) * numberMysqlData);
    } else {
        if(numberMysqlData < number) {
            //m_poolEx->SKP_PFREE(*datas);
            for(int i = 0; i < numberMysqlData; i++) {
                skp_pool_free(m_poolEx, (*datas)[i].buffer);
            }
            skp_pool_free(m_poolEx, *datas);
            numberMysqlData = number;
            *datas = (SkpMysqlData_t *)skp_pool_calloc(m_poolEx, sizeof(SkpMysqlData_t) * numberMysqlData);
        } else {
            for(int i = 0; i < numberMysqlData; i++) {
                char *buffer = (*datas)[i].buffer;
                uint64 bufferLen = (*datas)[i].bufferLen;
                m_poolEx->memset(&(*datas)[i], 0x00, sizeof(SkpMysqlData_t));
                (*datas)[i].buffer = buffer;
                (*datas)[i].bufferLen = bufferLen;
            }
        }
    }
}

void SkpMysqlConn::skp_check_mysql_data(SkpMysqlData_t *data)
{
    uint64 bufferSize = data->dataLenMax + 1;
    bufferSize = ((bufferSize / 512) + 1) * 512;

    if(data->buffer == NULL) {
        data->bufferLen = bufferSize;
        data->buffer = (char *)skp_pool_calloc(m_poolEx, data->bufferLen);
    } else {
        if(data->bufferLen < bufferSize) {
            //m_poolEx->SKP_PFREE(data->buffer);
            skp_pool_free(m_poolEx, data->buffer);
            data->bufferLen = bufferSize;
            data->buffer = (char *)skp_pool_calloc(m_poolEx, data->bufferLen);
        } else {
            m_poolEx->memset(data->buffer, 0x00, data->bufferLen);
        }
    }
}

void SkpMysqlConn::skp_copy_mysql_data(SkpMysqlData_t *des, SkpMysqlData_t *src)
{
    if(src->buffer) {
        des->dataLenMax = src->bufferLen;
        skp_check_mysql_data(des);
    }
    char *buffer = des->buffer;
    uint64 bufferLen =  des->bufferLen;
    uint64 dataLenMax = des->dataLenMax;
    memcpy(des, src, sizeof(SkpMysqlData_t));
    des->buffer = buffer;
    des->bufferLen = bufferLen;
    des->dataLenMax = dataLenMax;

    if(src->buffer) {
        memcpy(des->buffer, src->buffer, src->bufferLen);
    }
}

bool SkpMysqlConn::skp_is_more(int size)
{
    return size >= DATA_CACHE_MAX;
}

void SkpMysqlConn::skp_param_char(char ch)
{
    SKP_ASSERT(m_numberParam < m_paramCount);
    SkpMysqlData_t *data = &m_data[m_numberParam];
    data->isNULL = 0;
    data->dataLen = sizeof(char);
    memcpy(data->data, &ch, data->dataLen);

    MYSQL_BIND *bind = &m_bind[m_numberParam];
    bind->buffer_type = MYSQL_TYPE_TINY;
    bind->buffer = data->data;
    bind->buffer_length = DATA_CACHE_MAX;
    bind->length = (unsigned long *)&data->dataLen;
    bind->is_null = &data->isNULL;

    m_numberParam++;
}

void SkpMysqlConn::skp_param_short(uint16 sh)
{
    SKP_ASSERT(m_numberParam < m_paramCount);
    SkpMysqlData_t *data = &m_data[m_numberParam];
    data->isNULL = 0;
    data->dataLen = sizeof(uint16);
    memcpy(data->data, &sh, data->dataLen);

    MYSQL_BIND *bind = &m_bind[m_numberParam];
    bind->buffer_type = MYSQL_TYPE_SHORT;
    bind->buffer = data->data;
    bind->buffer_length = DATA_CACHE_MAX;
    bind->length = (unsigned long *)&data->dataLen;
    bind->is_null = &data->isNULL;

    m_numberParam++;
}

void SkpMysqlConn::skp_param_int(uint in)
{
    SKP_ASSERT(m_numberParam < m_paramCount);
    SkpMysqlData_t *data = &m_data[m_numberParam];
    data->isNULL = 0;
    data->dataLen = sizeof(uint);
    memcpy(data->data, &in, data->dataLen);

    MYSQL_BIND *bind = &m_bind[m_numberParam];
    bind->buffer_type = MYSQL_TYPE_LONG;
    bind->buffer = data->data;
    bind->buffer_length = DATA_CACHE_MAX;
    bind->length = (unsigned long *)&data->dataLen;
    bind->is_null = &data->isNULL;

    m_numberParam++;
}

void SkpMysqlConn::skp_param_large_int(uint64 largeInt)
{
    SKP_ASSERT(m_numberParam < m_paramCount);
    SkpMysqlData_t *data = &m_data[m_numberParam];
    data->isNULL = 0;
    data->dataLen = sizeof(uint64);
    memcpy(data->data, &largeInt, data->dataLen);

    MYSQL_BIND *bind = &m_bind[m_numberParam];
    bind->buffer_type = MYSQL_TYPE_LONGLONG;
    bind->buffer = data->data;
    bind->buffer_length = DATA_CACHE_MAX;
    bind->length = (unsigned long *)&data->dataLen;
    bind->is_null = &data->isNULL;

    m_numberParam++;
}

void SkpMysqlConn::skp_param_double(double d)
{
    SKP_ASSERT(m_numberParam < m_paramCount);
    SkpMysqlData_t *data = &m_data[m_numberParam];
    data->isNULL = 0;
    data->dataLen = sizeof(double);
    memcpy(data->data, &d, data->dataLen);

    MYSQL_BIND *bind = &m_bind[m_numberParam];
    bind->buffer_type = MYSQL_TYPE_DOUBLE;
    bind->buffer = data->data;
    bind->buffer_length = DATA_CACHE_MAX;
    bind->length = (unsigned long *)&data->dataLen;
    bind->is_null = &data->isNULL;

    m_numberParam++;
}

void SkpMysqlConn::skp_param_buffer(const char *p, int size)
{
    SKP_ASSERT(m_numberParam < m_paramCount);
    SkpMysqlData_t *data = &m_data[m_numberParam];
    data->isNULL = 0;
    data->dataLenMax = size;
    data->dataLen = size;
    if(!skp_is_more(data->dataLenMax)) {
        memcpy(data->data, p, data->dataLen);
    } else {
        skp_check_mysql_data(data);
        memcpy(data->buffer, p, data->dataLen);
    }


    MYSQL_BIND *bind = &m_bind[m_numberParam];
    bind->buffer_type = MYSQL_TYPE_VAR_STRING;

    if(!skp_is_more(data->dataLenMax)) {
        bind->buffer = data->data;
        bind->buffer_length = DATA_CACHE_MAX;
    } else {
        bind->buffer = data->buffer;
        bind->buffer_length = data->bufferLen;
    }

    bind->length = (unsigned long *)&data->dataLen;
    bind->is_null = &data->isNULL;

    m_numberParam++;
}

void SkpMysqlConn::skp_param_null()
{
    SKP_ASSERT(m_numberParam < m_paramCount);
    SkpMysqlData_t *data = &m_data[m_numberParam];
    data->isNULL = 0;
    data->dataLen = 0;

    MYSQL_BIND *bind = &m_bind[m_numberParam];
    bind->buffer_type = MYSQL_TYPE_NULL;
    bind->buffer = data->data;
    bind->buffer_length = DATA_CACHE_MAX;
    bind->length = (unsigned long *)&data->dataLen;
    bind->is_null = &data->isNULL;

    m_numberParam++;
}

char SkpMysqlConn::skp_field_char()
{
    SkpMysqlResultData_t *datas = m_currMysqlResult->currMysqlResultData;
    SKP_ASSERT(datas->currMysqlData < datas->numberMysqlDataReal);
    SkpMysqlData_t *data = &datas->data[datas->currMysqlData];
    datas->currMysqlData++;

    SKP_ASSERT(data->type == MYSQL_TYPE_TINY);
    SKP_ASSERT(!data->isNULL);
    char *ch = (char *)data->data;
    if(skp_is_more(data->dataLenMax)) {
        ch = (char *)data->buffer;
    }

    return *ch;
}

uint16 SkpMysqlConn::skp_field_short()
{
    SkpMysqlResultData_t *datas = m_currMysqlResult->currMysqlResultData;
    SKP_ASSERT(datas->currMysqlData < datas->numberMysqlDataReal);
    SkpMysqlData_t *data = &datas->data[datas->currMysqlData];
    datas->currMysqlData++;

    SKP_ASSERT(data->type == MYSQL_TYPE_SHORT);
    SKP_ASSERT(!data->isNULL);
    uint16 *ch = (uint16 *)data->data;
    if(skp_is_more(data->dataLenMax)) {
        ch = (uint16 *)data->buffer;
    }

    return *ch;
}

uint SkpMysqlConn::skp_field_int()
{
    SkpMysqlResultData_t *datas = m_currMysqlResult->currMysqlResultData;
    SKP_ASSERT(datas->currMysqlData < datas->numberMysqlDataReal);
    SkpMysqlData_t *data = &datas->data[datas->currMysqlData];
    datas->currMysqlData++;

    SKP_ASSERT(data->type == MYSQL_TYPE_LONG);
    SKP_ASSERT(!data->isNULL);
    uint *ch = (uint *)data->data;
    if(skp_is_more(data->dataLenMax)) {
        ch = (uint *)data->buffer;
    }

    return *ch;
}

uint64 SkpMysqlConn::skp_field_large_int()
{
    SkpMysqlResultData_t *datas = m_currMysqlResult->currMysqlResultData;
    SKP_ASSERT(datas->currMysqlData < datas->numberMysqlDataReal);
    SkpMysqlData_t *data = &datas->data[datas->currMysqlData];
    datas->currMysqlData++;

    SKP_ASSERT(data->type == MYSQL_TYPE_LONGLONG);
    SKP_ASSERT(!data->isNULL);
    uint64 *ch = (uint64 *)data->data;
    if(skp_is_more(data->dataLenMax)) {
        ch = (uint64 *)data->buffer;
    }

    return *ch;
}

double SkpMysqlConn::skp_field_double()
{
    SkpMysqlResultData_t *datas = m_currMysqlResult->currMysqlResultData;
    SKP_ASSERT(datas->currMysqlData < datas->numberMysqlDataReal);
    SkpMysqlData_t *data = &datas->data[datas->currMysqlData];
    datas->currMysqlData++;

    SKP_ASSERT(data->type == MYSQL_TYPE_DOUBLE);
    SKP_ASSERT(!data->isNULL);
    double *ch = (double *)data->data;
    if(skp_is_more(data->dataLenMax)) {
        ch = (double *)data->buffer;
    }

    return *ch;
}

char *SkpMysqlConn::skp_field_buffer(int &size)
{
    SkpMysqlResultData_t *datas = m_currMysqlResult->currMysqlResultData;
    SKP_ASSERT(datas->currMysqlData < datas->numberMysqlDataReal);
    SkpMysqlData_t *data = &datas->data[datas->currMysqlData];
    datas->currMysqlData++;

    SKP_ASSERT(data->type == MYSQL_TYPE_VAR_STRING);
    SKP_ASSERT(!data->isNULL);
    size = data->dataLen;
    char *str = (char *)data->data;
    if(skp_is_more(data->dataLenMax)) {
        str = (char *)data->buffer;
    }

    return str;
}

