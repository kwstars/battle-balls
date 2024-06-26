SKYNET_PATH ?= ./skynet
LUA_INCLUDE_DIR = /usr/include/lua5.4
LUA_CMODULE_DIR = /usr/lib/x86_64-linux-gnu/lua/5.4
CURDIR = $(shell pwd)
LUA_CLIB_DIR = luaclib

.PHONY: init clean

init:
	git submodule update --init
	cd $(SKYNET_PATH) && git checkout v1.7.0 && $(MAKE) PLAT='linux' && cd ..
	cd luaclib-src/lua-cjson && git checkout 2.1.0 && \
	make LUA_INCLUDE_DIR=$(LUA_INCLUDE_DIR) LUA_CMODULE_DIR=$(LUA_CMODULE_DIR) && \
	make install DESTDIR=$(CURDIR) LUA_CMODULE_DIR=$(LUA_CLIB_DIR) && cd ../../
	cd luaclib-src/lua-protobuf && git checkout 0.5.2 && gcc -O2 -shared -fPIC -I$(LUA_INCLUDE_DIR) pb.c -o pb.so \
	&& mv pb.so $(CURDIR)/$(LUA_CLIB_DIR) && cd ../../

clean:
	cd $(SKYNET_PATH) && $(MAKE) clean
	rm -f $(LUA_CLIB_DIR)/*.so