#!/bin/sh

cd $(dirname $0)
. ./conf.sh

rm -rf $REDIS_PATH
rm -rf $REDIS_LOG_PATH
