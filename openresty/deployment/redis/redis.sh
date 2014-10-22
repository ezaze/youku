#!/bin/sh

function init()
{
    cd $(dirname $0)
    . ./conf.sh
}

function start()
{
    pushd ${REDIS_PATH}
    p=6371
    while [ $p -le 6382 ]; do
        if [ -n "$1" ]; then
            ${REDIS_PATH}/bin/redis-server redis.conf --port $p --slaveof $1 $p --logfile $REDIS_PATH/logs/$p.log &
            echo "${REDIS_PATH}/bin/redis-server redis.conf --port $p --slaveof $1 $p --logfile $REDIS_PATH/logs/$p.log &"
        else
#            ${REDIS_PATH}/bin/redis-server redis.conf --port $p --logfile $REDIS_PATH/logs/$p.log --dbfilename $p.rdb  --save 86400 1 &
#            echo "${REDIS_PATH}/bin/redis-server redis.conf --port $p --logfile logs/$p.log --dbfilename $p.rdb  --save 86400 1 &"
            ${REDIS_PATH}/bin/redis-server redis.conf --port $p --logfile $REDIS_PATH/logs/$p.log &
            echo "${REDIS_PATH}/bin/redis-server redis.conf --port $p --logfile $REDIS_PATH/logs/$p.log &"
        fi
        p=$(($p+1))
    done
    popd
}

function stop()
{
    name="${REDIS_PATH}/bin/redis-server"
    for pid in `ps -ef | grep $name | awk '{if ($8 == "/usr/local/redis/bin/redis-server") print $2}'` ; do
        kill -9 $pid
        echo "kill -9 $pid"
    done
}

if [ "$#" != "1" ] && [ "$#" != "2" ]; then
    echo "usage: redis.sh start|stop|restart [ip](master ip if server is slave)"
    exit 1;
fi

op=$1

init
case "$op" in
    start)
        if [ "$#" == "2" ]; then
            start $2
        else
            start
        fi
    ;;
    
    stop)
        stop
    ;;
    
    restart)
        stop
        if [ "$#" == "2" ]; then
            start $2
        else
            start
        fi
        
    ;;

    *)
        echo "usage: redis.sh start|stop|restart [ip](master ip if server is slave)"
        exit 1
    ;;
esac

