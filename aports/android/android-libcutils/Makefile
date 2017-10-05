LD := gcc
LDFLAGS := -L/usr/lib/android/ -shared
LIBS := -l:liblog.so
CXX := g++
CXXFLAGS := -std=c++14 -Wall -I../include -fPIC
CC := gcc

# char16_t workaround: https://stackoverflow.com/a/22369822
CFLAGS := -Wall -I../include -Dchar16_t=uint16_t -fPIC

# From Android.mk: libcutils_common_sources, libcutils_nonwindows_sources
SRC_C := \
        atomic.c \
        config_utils.c \
        fs_config.c \
        canned_fs_config.c \
        hashmap.c \
        iosched_policy.c \
        load_file.c \
        native_handle.c \
        open_memstream.c \
        process_name.c \
        record_stream.c \
        sched_policy.c \
        strdup16to8.c \
        strdup8to16.c \
        strlcpy.c \
        threads.c \
        fs.c \
        multiuser.c \
        socket_inaddr_any_server_unix.c \
        socket_local_client_unix.c \
        socket_local_server_unix.c \
        socket_loopback_client_unix.c \
        socket_loopback_server_unix.c \
        socket_network_client_unix.c \
        str_parms.c

SRC_CPP := \
        sockets_unix.cpp \
        sockets.cpp

OBJECTS := $(SRC_C:%.c=%.c.o) $(SRC_CPP:%.cpp=%.cpp.o)

all: libcutils.so

%.c.o: %.c
	$(info CC $<)
	@$(CC) -c -o $@ $< $(CFLAGS)

%.cpp.o: %.cpp
	$(info CC $<)
	@$(CXX) -c -o $@ $< $(CXXFLAGS)

libcutils.so: $(OBJECTS)
	$(info LD $@)
	@$(LD) -o $@ $^ $(LDFLAGS) $(LIBS)

.PHONY: clean

clean:
	rm -v libcutils.so *.o
