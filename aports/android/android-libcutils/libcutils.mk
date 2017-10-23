NAME = libcutils
SOURCES = atomic.c \
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
          sockets.cpp \
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
          sockets_unix.cpp \
          str_parms.c \
          ashmem-host.c \
          trace-host.c \
          dlmalloc_stubs.c
SOURCES := $(foreach source, $(SOURCES), libcutils/$(source))
CPPFLAGS += -Iinclude -Dchar16_t=uint16_t -fPIC
LDFLAGS += -shared -Wl,-soname,$(NAME).so.0 \
           -Wl,-rpath=/usr/lib/android -lpthread -L/usr/lib/android -llog

build: $(SOURCES)
	$(CC) $^ -o $(NAME).so.0 $(CFLAGS) $(CPPFLAGS) $(LDFLAGS)
	ln -s $(NAME).so.0 $(NAME).so

clean:
	$(RM) $(NAME).so*
