# From Android.mk: liblog_sources, liblog_host_sources, LOCAL_SRC_FILES_linux
SRC_C := \
	config_write.c \
	event_tag_map.c \
	fake_log_device.c \
	fake_writer.c \
	log_event_list.c \
	log_event_write.c \
	logger_lock.c \
	logger_name.c \
	logger_write.c
OBJECTS := $(SRC_C:%.c=%.o)
CC := gcc
LD := gcc
LDFLAGS := -shared
CFLAGS := -Wall -I../include -fPIC

all: liblog.so

%.o: %.c
	$(info CC $<)
	@$(CC) -c -o $@ $< $(CFLAGS)

liblog.so: $(OBJECTS)
	$(info LD $@)
	@$(LD) -o $@ $^ $(LDFLAGS)

.PHONY: clean

clean:
	rm -v *.o liblog.so
