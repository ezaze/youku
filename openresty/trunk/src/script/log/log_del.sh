#! /bin/sh

del_date=$(date +"%Y%m%d" -d -9day)
backup_dir1=/data2/sax/back
backup_dir2=/data3/sax/back
flag_file=/data1/sax/logs/flag

rm -rf ${backup_dir1}/${del_date}*.tar.gz
rm -rf ${backup_dir2}/${del_date}*.tar.gz

if [ -f ${flag_file} ]; then
    rm -rf ${flag_file}
else
    touch ${flag_file}
fi

