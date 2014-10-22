#!/bin/sh

function init()
{
    cd $(dirname $0)
    . ./conf.sh

    rm -rf $REDIS_PATH
    mkdir $REDIS_PATH

    pushd $REDIS_PATH
        local file=redis-${REDIS_VERSION}.tar.gz
        svn export $SVN_SERVER/software/trunk/$file
        tar -zxf $file

        svn export ${SVN_SERVER}/deployment/trunk/redis/redis.conf
    popd
}

function install()
{
    pushd $REDIS_PATH
        pushd redis-$REDIS_VERSION
            make
            make PREFIX=$REDIS_PATH install
        popd

        mkdir -p ${REDIS_LOG_PATH}/logs
        mkdir -p ${REDIS_LOG_PATH}/dump
        ln -s ${REDIS_LOG_PATH}/logs $REDIS_PATH/logs
        ln -s ${REDIS_LOG_PATH}/dump $REDIS_PATH/dump
    popd
}

init
install
