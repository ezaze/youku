#! /bin/sh

init () {
    logs_dir=/data1/sax/logs

    backup_date=$(date +"%Y%m%d%H")
    if [ -f ${logs_dir}/flag ]; then
        backup_dir=/data2/sax/back
    else
        backup_dir=/data3/sax/back        
    fi

    if [ -f ${logs_dir}/nginx.pid ];then
        pid=`cat ${logs_dir}/nginx.pid`
    else
        pid=`ps -ef | grep 'nginx' | grep 'master' | awk '{print $2}'`
    fi
}

rotate() {
    mkdir ${backup_date}
    mv access.log ${backup_date}
    mv impress.log ${backup_date}
    mv view.log ${backup_date}
    mv click.log ${backup_date}

    kill -USR1 $pid
}

backup(){
    tar -czf ${backup_dir}/${backup_date}.tar.gz ${backup_date}
    rm -rf ${backup_date}	 
}


main () {
    init
    cd $logs_dir	
    rotate
    backup 

}

main
