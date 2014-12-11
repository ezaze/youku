#!/bin/sh

function init()
{
    cd $(dirname $0)
    source ./conf.sh
    
    rm -rf $CODE_DIR
    svn export $SVN_URL/adx/$version $CODE_DIR
}

function deploy()
{
    pushd $CODE_DIR
        rm -rf $NGINX_PATH/conf/*
        cp -a conf/* $NGINX_PATH/conf

        rm -rf $NGINX_PATH/src/*
        cp -a src/lua src/script $NGINX_PATH/src

        rm -rf $NGINX_PATH/www/*
        cp -a www/* $NGINX_PATH/www
    popd

    pushd $NGINX_PATH/conf
        sed -i "s@%NGINX_PATH%@$NGINX_PATH@g" *.conf
        sed -i "s/%SERVER_TYPE%/$server/g" *.conf
        sed -i "s/%IDC_NAME%/$idc/g" *.conf

        case $idc in
            bx)
                sed -i "s/%DNS_SERVER%/$BX_DNS_SERVER/g" *.conf
                ;;

            sx)
                sed -i "s/%DNS_SERVER%/$SX_DNS_SERVER/g" *.conf
                ;;

            yf)
                sed -i "s/%DNS_SERVER%/$YF_DNS_SERVER/g" *.conf
                ;;

            *)
                echo "unknown idc $idc"
                exit 1
                ;;
       esac
    popd
}

function usage()
{
if [ -n "$1" ]; then
    echo $1
fi
cat << END
usage:
    -h       print this message
    -i       set idc (yf|bx|sx), must be set
    -v       set project version (dev|version), defaut to dev, dev=trunk,version=branch-version
             the format of version is [0-9].[0-9].[0-9]
    -s       set server type (worker|master), defaut to cluster"
END
}

while getopts hi:v:s: option
do
    v=$OPTARG
    case "$option" in
        h) 
            usage
            exit 0
        ;;

        i)
            if [ "$v" != "yf" ] && [ "$v" != "bx" ] && [ "$v" != "sx" ]; then
                usage "$0: invalid idc arg $v"
                exit 1
            fi
            idc=$v
        ;;
        
        v)
            if [ "$v" == "dev" ]; then
                version=trunk
            elif [ `echo $v | grep "^[0-9]\.[0-9]\.[0-9]$"` ]; then
                version="branches/branch-$v"
            else
                usage "$0: invalid version arg $v"
                exit 1
            fi
        ;;

        s)
            if [ "$v" != "worker" ] && [ "$v" != "master" ]; then
                usage "$0: invalid server arg $v"
                exit 1
            fi
            server=$v
        ;;
       
        *)  
            usage
            exit 1
        ;;
    esac
done

if [ -z "$idc" ]; then
    usage "idc must be set, please use -i option"
    exit 1
fi

if [ -z "$version" ]; then
    version=trunk
fi

if [ -z "$server" ]; then
    server=worker
fi

init
deploy

