SKYNET_PATH?=./skynet

init:
	git submodule update --init
	cd $(SKYNET_PATH) && git checkout v1.7.0 && $(MAKE) PLAT='linux' && cd ..
	cd luaclib-src/lua-cjson && git checkout 2.1.0 && \
	make LUA_INCLUDE_DIR=/usr/include/lua5.4 LUA_CMODULE_DIR=/usr/lib/x86_64-linux-gnu/lua/5.4 && \
	make install DESTDIR=$(CURDIR) LUA_CMODULE_DIR=luaclib && cd ../../

clean:
	cd $(SKYNET_PATH) && $(MAKE) clean