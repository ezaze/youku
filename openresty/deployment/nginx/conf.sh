#!/bin/sh

SVN_URL=https://svn1.intra.sina.com.cn/adsystem/AdEngine/adx

SOFTWARE_DIR=/data0/sax/software
CODE_DIR=/data0/sax/code

DRIZZLE_VERSION=drizzle7-2011.07.21 
EXPAT_VERSION=expat-2.1.0
OPENRESTY_VERSION=ngx_openresty-1.7.2.1
CONSISTENT_HASH_VERSION=ngx_http_consistent_hash-1.0 
RESTY_HTTP_VERSION=lua_resty_http-0.1
UUID_VERSION=uuid-0.1
STRUCT_VERSION=struct-0.2
LUAEXPAT_VERSION=luaexpat-1.2.0

OPENRESTY_PATH=/usr/local/openresty
NGINX_PATH=$OPENRESTY_PATH/nginx
LUAJIT_INC_PATH=$OPENRESTY_PATH/luajit/include/luajit-2.1
LUAJIT_LIB_PATH=$OPENRESTY_PATH/luajit/lib
LUALIB_PATH=$OPENRESTY_PATH/lualib

SAX_LOGS_DIR=/data1/sax/logs
SAX_BACK1_DIR=/data2/sax/back
SAX_BACK2_DIR=/data3/sax/back

BX_DNS_SERVER=10.13.8.25
SX_DNS_SERVER=10.71.16.177
YF_DNS_SERVER=172.16.139.249

SAX_INIT_URL=http://127.0.0.1/sax/initobject
SAXMOB_INIT_URL=http://127.0.0.1/business/init

