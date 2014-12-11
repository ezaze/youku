#!/bin/sh

function init()
{
    cd $(dirname $0)
    source ./conf.sh

    rm -rf $SOFTWARE_DIR
    svn export $SVN_URL/software/trunk $SOFTWARE_DIR
}

function install_dependency()
{
    pushd $SOFTWARE_DIR
        tar -zxvf $DRIZZLE_VERSION.tar.gz
        pushd $DRIZZLE_VERSION
            ./configure --without-server
            make libdrizzle-1.0
            make install-libdrizzle-1.0
        popd

        tar -zxvf $EXPAT_VERSION.tar.gz
        pushd $EXPAT_VERSION
            ./configure
            make
            make install
        popd
    popd
    
    pushd /etc/ld.so.conf.d/
        echo "/usr/local/lib" >usr_local_lib.conf
        ldconfig
    popd
}

function install_openresty()
{
    pushd $SOFTWARE_DIR
        tar -zxvf $OPENRESTY_VERSION.tar.gz
        tar -zxvf $CONSISTENT_HASH_VERSION.tar.gz
        pushd $OPENRESTY_VERSION
            ./configure --prefix=$OPENRESTY_PATH \
                        --with-luajit \
                        --with-http_drizzle_module \
                        --add-module=$SOFTWARE_DIR/$CONSISTENT_HASH_VERSION
            make
            make install
        popd

        tar -zxvf $RESTY_HTTP_VERSION.tar.gz
        pushd $RESTY_HTTP_VERSION
            cp http.lua $LUALIB_PATH/resty
        popd

        tar -zxvf $UUID_VERSION.tar.gz
        pushd $UUID_VERSION
            make LUAINC=$LUAJIT_INC_PATH
            cp -a uuid.so $LUALIB_PATH
        popd 

        tar -zxvf $STRUCT_VERSION.tar.gz
        pushd $STRUCT_VERSION
            make LUADIR=$LUAJIT_INC_PATH
            cp -a struct.so $LUALIB_PATH
        popd 

        tar -zxvf $LUAEXPAT_VERSION.tar.gz
        pushd $LUAEXPAT_VERSION
            make LUA_INC=$LUAJIT_INC_PATH
            cp -a src/lxp.so $LUALIB_PATH
        popd
    popd

    mkdir -p $NGINX_PATH/src
    mkdir -p $NGINX_PATH/www
    mkdir -p $SAX_LOGS_DIR
    rm -rf $NGINX_PATH/logs
    ln -s $SAX_LOGS_DIR $NGINX_PATH/logs
    mkdir -p $SAX_BACK1_DIR
    mkdir -p $SAX_BACK2_DIR
}

init
install_dependency
install_openresty

