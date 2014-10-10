#!/usr/bin/env python
# encoding: utf-8
from datetime import datetime,timedelta
import os


###开始过滤日志
print datetime.now().strftime("%Y-%m-%d-%H-%M") + ":  dsp.py start..."

#
yesterday=(datetime.now()+ timedelta(days=-1))
rfile="/data/logs/dsp_masky/%s/bid-10008_%s.log" % (yesterday.strftime("%Y/%m"),yesterday.strftime("%Y%m%d"))

wfile="/data/backup/logs/dsp_masky/bid/%s/" % yesterday.strftime("%Y/%m") + "bid-10008_%s-express.log" % yesterday.strftime("%Y%m%d")

r=open(rfile)
w=open(wfile,'w')

def combine(dict,str):
    try:
        tmp=dict[str]
        return tmp
    except KeyError:
        return ""


result=dict()
line = r.readline()
while line:
    parts=line.split('\t')
    result['time']=parts[0]
    for part in parts[1:-1]:
        try:
            result[part.split('=')[0]]=part.split('=')[1]
        except IndexError:
            pass

    str=""
    str+=(combine(result,"time")+'\t')
    str+=(combine(result,"rid")+'\t')
    str+=(combine(result,"u")+'\t')
    str+=(combine(result,"au")+'\t')
    str+=(combine(result,"ip")+'\t')
    str+=(combine(result,"chn")+'\t')
    str+=(combine(result,"imid")+'\t')
    str+=(combine(result,"of")+'\t')
    str+=(combine(result,"cls")+'\t')
    str+=(combine(result,"aspt")+'\t')
    str+=(combine(result,"spt")+'\t')
    str+=(combine(result,"ospt")+'\t')
    str+=(combine(result,"pr")+'\t')
    str+=(combine(result,"c")+'\t')
    str+=(combine(result,"p")+'\t')
    str+=(combine(result,"s")+'\t')
    str+=(combine(result,"sc")+'\t')
    str+=(combine(result,"bf")+'\t')
    str+=(combine(result,"srn")+'\t')
    str+=(combine(result,"swh")+'\t')
    str+=(combine(result,"sht")+'\t')
    str+=(combine(result,"ctb")+'\t')
    str+=(combine(result,"mtb")+'\t')
    str+=(combine(result,"ct")+'\t')
    str+=(combine(result,"tv")+'\t')
    str+=(combine(result,"ldp")+'\t')
    str+=(combine(result,"vid")+'\t')
    str+=(combine(result,"sid")+'\t')
    str+=(combine(result,"uid")+'\n')

    w.write(str)
    line = r.readline()

r.close()
w.close()

#压缩过滤后的日志
cmd = "tar -czvf " + wfile + ".tgz" + " " + wfile
os.system(cmd)

#打印过滤后日志和压缩日志大小到脚本日志中
print rfile + ": size is " + str(os.path.getsize(rfile)/1024/1024) + "MB"
print wfile + ": size is " + str(os.path.getsize(wfile)/1024/1024) + "MB"

#删除过滤后日志和原始日志
cmd = "rm -rf " + wfile
os.system(cmd)

cmd = "rm -rf " + rfile
os.system(cmd)

print datetime.now().strftime("%Y-%m-%d-%H-%M") + ":  dsp.py end..."
