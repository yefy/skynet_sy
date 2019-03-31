CC = gcc
CFLAGS = -O2 -fPIC -Wall
#LUADIR = /usr/local/include
LUADIR = /home/yfy/study/skp/skynet_sy/skynet-1.2.0/3rd/lua
TARGET = protobuf.so

.PHONY : all clean

all : $(TARGET)

$(TARGET) : pbc-lua53.c
	$(CC) $(CFLAGS) -shared -o $@ -I../.. -I$(LUADIR) -L../../build $^ -lpbc

clean :
	rm -f $(TARGET)
