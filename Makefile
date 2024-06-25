init:
	git submodule update --init
	cd skynet && git checkout v1.7.0 && make linux && cd ..
	cd luaclib-src/lua-cjson && git checkout 2.1.0 && \
	make LUA_INCLUDE_DIR=/usr/include/lua5.4 LUA_CMODULE_DIR=/usr/lib/x86_64-linux-gnu/lua/5.4 && \
	make install DESTDIR=$(CURDIR) LUA_CMODULE_DIR=luaclib && cd ../../
