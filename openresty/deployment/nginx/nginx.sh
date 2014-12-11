#!/bin/sh

function init()
{
    cd $(dirname $0)
    source ./conf.sh
}

function start() 
{
    echo "$NGINX_PATH/sbin/nginx -p $NGINX_PATH/"
    $NGINX_PATH/sbin/nginx -p $NGINX_PATH/

    sleep 1s

    if [ "$server" = "worker" ]; then
        echo "curl $SAX_INIT_URL"
        curl $SAX_INIT_URL

        echo "curl $SAXMOB_INIT_URL"
        curl $SAXMOB_INIT_URL
    fi
}
 
function stop() 
{
    if [ -f "$NGINX_PATH/logs/nginx.pid" ]; then
        pid=$(cat $NGINX_PATH/logs/nginx.pid)
    else
        pid=$(ps -ef | grep 'nginx' | grep 'master' | awk '{print $2}')
    fi

    echo "kill -INT $pid"
    kill -INT $pid
}

function execute()
{
    case $command in
        start)
            start
            ;;

        stop)
            stop
            ;;

        restart)
            stop
            sleep 3s
            start
            ;;

        *)
            echo "unknown command $command" 
            exit 1
            ;;
    esac
}

function usage()
{
    cat << _EOF_
usage:
  -h    help
  -s    server type: worker|master
  -c    command type: start|stop|restart
_EOF_
}

while getopts hs:c: opt; do
    case $opt in
        h)
            usage
            exit 0
            ;;

        s)
            server=$OPTARG
            ;;

        c)
            command=$OPTARG
            ;;

        "?")
            exit 1
            ;;

        *)
            echo "internal error"
            exit 1
            ;;
    esac
done

init
execute

