apt-get install libreadline-dev autoconf
yum install -y readline-devel autoconf
make linux MALLOC_STATICLIB= SKYNET_DEFINES=-DNOUSE_JEMALLOC

