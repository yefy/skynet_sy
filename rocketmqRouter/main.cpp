///*
//* Licensed to the Apache Software Foundation (ASF) under one or more
//* contributor license agreements.  See the NOTICE file distributed with
//* this work for additional information regarding copyright ownership.
//* The ASF licenses this file to You under the Apache License, Version 2.0
//* (the "License"); you may not use this file except in compliance with
//* the License.  You may obtain a copy of the License at
//*
//*     http://www.apache.org/licenses/LICENSE-2.0
//*
//* Unless required by applicable law or agreed to in writing, software
//* distributed under the License is distributed on an "AS IS" BASIS,
//* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//* See the License for the specific language governing permissions and
//* limitations under the License.
//*/
//#include <stdio.h>
//#include <stdlib.h>
//#include <string.h>

//#include <condition_variable>
//#include <iomanip>
//#include <iostream>
//#include <mutex>
//#include <thread>

//#include "common.h"

//using namespace rocketmq;

//std::condition_variable g_finished;
//std::mutex g_mtx;
//std::atomic<bool> g_quit(false);

//class SelectMessageQueueByHash : public MessageQueueSelector {
// public:
//  MQMessageQueue select(const std::vector<MQMessageQueue>& mqs, const MQMessage& msg, void* arg) {
//    int orderId = *static_cast<int*>(arg);
//    int index = orderId % mqs.size();
//    return mqs[index];
//  }
//};

//SelectMessageQueueByHash g_mySelector;

//void ProducerWorker(RocketmqSendAndConsumerArgs* info, DefaultMQProducer* producer) {
//  while (!g_quit.load()) {
//    if (g_msgCount.load() <= 0) {
//      std::unique_lock<std::mutex> lck(g_mtx);
//      g_finished.notify_one();
//    }
//    MQMessage msg(info->topic,  // topic
//                  "*",          // tag
//                  info->body);  // body

//    int orderId = 1;
//    SendResult sendResult =
//        producer->send(msg, &g_mySelector, static_cast<void*>(&orderId), info->retrytimes, info->SelectUnactiveBroker);
//    --g_msgCount;
//  }
//}

//int main(int argc, char* argv[]) {
//  RocketmqSendAndConsumerArgs info;
//  if (!ParseArgs(argc, argv, &info)) {
//    exit(-1);
//  }

//  DefaultMQProducer producer("please_rename_unique_group_name");
//  PrintRocketmqSendAndConsumerArgs(info);

//  producer.setNamesrvAddr(info.namesrv);
//  producer.setNamesrvDomain(info.namesrv_domain);
//  producer.setGroupName(info.groupname);
//  producer.setInstanceName(info.groupname);

//  producer.start();

//  int msgcount = g_msgCount.load();
//  std::vector<std::shared_ptr<std::thread>> work_pool;

//  int threadCount = info.thread_count;
//  for (int j = 0; j < threadCount; j++) {
//    std::shared_ptr<std::thread> th = std::make_shared<std::thread>(ProducerWorker, &info, &producer);
//    work_pool.push_back(th);
//  }

//  auto start = std::chrono::system_clock::now();
//  {
//    std::unique_lock<std::mutex> lck(g_mtx);
//    g_finished.wait(lck);
//    g_quit.store(true);
//  }

//  auto end = std::chrono::system_clock::now();
//  auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);

//  std::cout << "per msg time: " << duration.count() / (double)msgcount << "ms \n"
//            << "========================finished==============================\n";

//  for (size_t th = 0; th != work_pool.size(); ++th) {
//    work_pool[th]->join();
//  }

//  producer.shutdown();

//  return 0;
//}


















/*
* Licensed to the Apache Software Foundation (ASF) under one or more
* contributor license agreements.  See the NOTICE file distributed with
* this work for additional information regarding copyright ownership.
* The ASF licenses this file to You under the Apache License, Version 2.0
* (the "License"); you may not use this file except in compliance with
* the License.  You may obtain a copy of the License at
*
*     http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/
#include <stdlib.h>
#include <string.h>

#include <condition_variable>
#include <iomanip>
#include <iostream>
#include <map>
#include <mutex>
#include <thread>
#include <vector>

#include <skp_mysql_conn.h>
#include "common.h"

using namespace rocketmq;

std::condition_variable g_finished;
std::mutex g_mtx;
std::atomic<bool> g_quit(false);
TpsReportService g_tps;
std::atomic<int> g_consumedCount(0);


class SelectMessageQueueByHash : public MessageQueueSelector {
public:
    MQMessageQueue select(const std::vector<MQMessageQueue>& mqs, const MQMessage& msg, void* arg) {
        int orderId = *static_cast<int*>(arg);
        int index = orderId % mqs.size();
        return mqs[index];
    }
};

SelectMessageQueueByHash g_mySelector;

void ProducerWorker(RocketmqSendAndConsumerArgs* info, DefaultMQProducer* producer) {

    for( int i = 1; i <= g_msgCount.load(); ++i ){

        std::string body = info->body;
        int index = i;
        stringstream ss;
        ss<<index;
        string strIndex = ss.str();
        body += strIndex;
        MQMessage msg(info->topic,  // topic
                      "*",          // tag
                      body);  // body

        std::cout << "producer body = " << body << std::endl;

        try {
            index = 0;
            SendResult sendResult =
                    producer->send(msg, &g_mySelector, static_cast<void*>(&index), info->retrytimes, info->SelectUnactiveBroker);
        } catch (MQException& e) {
            std::cout << e << endl;  // if catch excepiton , need re-send this msg by
            // service
        }
    }
}



class MyMsgListener : public MessageListenerOrderly {
public:
    MyMsgListener() {}
    virtual ~MyMsgListener() {}

    virtual ConsumeStatus consumeMessage(const vector<MQMessageExt>& msgs) {
        for (size_t i = 0; i < msgs.size(); i++) {
            std::cout << msgs[i].toString() << std::endl;
            ++g_consumedCount;
            g_tps.Increment();
        }
        if (g_consumedCount.load() >= g_msgCount) {
            std::unique_lock<std::mutex> lK(g_mtx);
            g_quit.store(true);
            g_finished.notify_one();
        }
        return CONSUME_SUCCESS;
    }
};

 SkpMysqlConn *m_mysqlConn = new SkpMysqlConn();


 void createDb(){
     const char *mysqlHost = "192.168.123.22 ";
     const char *mysqlUser = "yefy";
     const char *mysqlPassword = "yfysina@389";
     const char *mysqlDatabase = "skynet_sy";
     m_mysqlConn->skp_connect(mysqlHost, mysqlUser, mysqlPassword, mysqlDatabase);
 }

void db_test() {
    const char *selectSql = "select id, regionName, serverName, userId, body from rocketmqRouter_select";
    m_mysqlConn->skp_prepare(selectSql);
    int res = m_mysqlConn->skp_execute();
    SKP_ASSERT(res == AF::Mysql_Error_Success);
    while(m_mysqlConn->skp_db_next()) {
        while(m_mysqlConn->skp_next()) {
            int id = m_mysqlConn->skp_field_int();
            printf("id = %d \n", id);
                    /*
            int passwordSize;
            char *password = m_mysqlConn->skp_field_buffer(passwordSize);
            int nameSize;
            char *name = m_mysqlConn->skp_field_buffer(nameSize);

            Friend::Friend *friendData = friendList.add_friend_();
            friendData->set_friend_(friend_);
            friendData->set_password(password, passwordSize);
            friendData->set_name(name, nameSize);


            printf("db userID = %lld, password = %s, name = %s \n", friend_, friendData->password().c_str(), friendData->name().c_str());
            */
        }
    }

}

int main(int argc, char* argv[]) {
    createDb();
    db_test();
    return 0;
    RocketmqSendAndConsumerArgs info;
    if (!ParseArgs(argc, argv, &info)) {
        exit(-1);
    }
    PrintRocketmqSendAndConsumerArgs(info);

    std::vector<std::shared_ptr<std::thread>> work_pool;

    DefaultMQProducer producer("please_rename_unique_group_name");
    producer.setNamesrvAddr(info.namesrv);
    producer.setGroupName("msg-persist-group_producer_sandbox");
    producer.start();
    std::shared_ptr<std::thread> th = std::make_shared<std::thread>(ProducerWorker, &info, &producer);
    work_pool.push_back(th);


    DefaultMQPushConsumer consumer("please_rename_unique_group_name");

    consumer.setNamesrvAddr(info.namesrv);
    consumer.setNamesrvDomain(info.namesrv_domain);
    consumer.setGroupName(info.groupname);
    consumer.setConsumeFromWhere(CONSUME_FROM_LAST_OFFSET);
    consumer.subscribe(info.topic, "*");
    consumer.setConsumeThreadCount(info.thread_count);
    consumer.setConsumeMessageBatchMaxSize(31);
    if (info.syncpush)
        consumer.setAsyncPull(false);

    MyMsgListener msglistener;
    consumer.registerMessageListener(&msglistener);
    g_tps.start();

    try {
        consumer.start();
    } catch (MQClientException& e) {
        std::cout << e << std::endl;
    }

    while (!g_quit.load()) {
        std::unique_lock<std::mutex> lk(g_mtx);
        g_finished.wait(lk);
    }

    for (size_t th = 0; th != work_pool.size(); ++th) {
        work_pool[th]->join();
    }

    producer.shutdown();
    consumer.shutdown();
    return 0;

}

