NAME = liblog
SOURCES = log_event_list.c log_event_write.c logger_write.c \
          config_write.c logger_name.c logger_lock.c \
          fake_log_device.c fake_writer.c \
          event_tag_map.c
SOURCES := $(foreach source, $(SOURCES), liblog/$(source))
CFLAGS += -fvisibility=hidden -fPIC
CPPFLAGS += -Iinclude \
            -DLIBLOG_LOG_TAG=1005 \
            -DFAKE_LOG_DEVICE=1 \
            -DSNET_EVENT_LOG_TAG=1397638484 \
			-fPIC
LDFLAGS += -shared -Wl,-soname,$(NAME).so.0 -lpthread

build: $(SOURCES)
	$(CC) $^ -o $(NAME).so.0 $(CFLAGS) $(CPPFLAGS) $(LDFLAGS)
	ln -s $(NAME).so.0 $(NAME).so

clean:
	$(RM) $(NAME).so*
