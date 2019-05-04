TEMPLATE = app
CONFIG += console c++11
CONFIG -= app_bundle
CONFIG -= qt
ROCKETMQ_DIR = ../../rocketmq/rocketmq-client-cpp-1.2.2
INCLUDEPATH += $${ROCKETMQ_DIR}/include $${ROCKETMQ_DIR}/bin/include /usr/include
LIBS += /usr/lib/x86_64-linux-gnu/libmysqlclient.a $${ROCKETMQ_DIR}/bin/librocketmq.a -lpthread -lz -ldl -lrt


#LIBS += -L$${ROCKETMQ_DIR}/bin -lrocketmq -lpthread -lz -ldl -lrt
#LIBS += -L$${ROCKETMQ_DIR}/bin -lrocketmq -L$${ROCKETMQ_DIR}/bin/lib -lboost_atomic -lboost_chrono -lboost_thread -lpthread -lz -ldl -lrt
#INCLUDEPATH += ../../rocketmq/rocketmq-client-cpp-1.2.2/include
#LIBS += -L../../rocketmq/rocketmq-client-cpp-1.2.2/bin -lrocketmq

SOURCES += main.cpp \
    skp_mysql_conn.cpp \
    skpAutoFree.cpp \
    skpUtility.cpp \
    skp_public_utility.cpp \
    skpMallocPoolEx.cpp \
    skpQueue.cpp \
    skpMalloc.cpp

HEADERS += \
    common.h \
    skp_mysql_conn.h \
    skpAutoFree.h \
    skpUtility.h \
    skp_public_utility.h \
    skpMallocPoolEx.h \
    skpQueue.h \
    skpMalloc.h
