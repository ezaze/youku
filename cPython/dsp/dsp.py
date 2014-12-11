#!/usr/bin/env python
# encoding: utf-8
from datetime import datetime,timedelta
import os


###开始过滤日志
print datetime.now().strftime("%Y-%m-%d-%H-%M") + ":  dsp.py start..."

#
yesterday=(datetime.now()+ timedelta(days=-1))
rfile="/home/sunbx/repo/youku/cPython/dsp/test/%s/bid-10008_%s.log" % (yesterday.strftime("%Y/%m"),yesterday.strftime("%Y%m%d"))

wfile="/home/sunbx/repo/youku/cPython/dsp/test/%s/" % yesterday.strftime("%Y/%m") + "bid-10008_%s-express.log" % yesterday.strftime("%Y%m%d")

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

    str_line=""
    str_line+=(combine(result,"time")+'\t')
    str_line+=(combine(result,"rid")+'\t')
    str_line+=(combine(result,"u")+'\t')
    str_line+=(combine(result,"au")+'\t')
    str_line+=(combine(result,"ip")+'\t')
    str_line+=(combine(result,"chn")+'\t')
    str_line+=(combine(result,"imid")+'\t')
    str_line+=(combine(result,"of")+'\t')
    str_line+=(combine(result,"cls")+'\t')
    str_line+=(combine(result,"aspt")+'\t')
    str_line+=(combine(result,"spt")+'\t')
    str_line+=(combine(result,"ospt")+'\t')
    str_line+=(combine(result,"pr")+'\t')
    str_line+=(combine(result,"c")+'\t')
    str_line+=(combine(result,"p")+'\t')
    str_line+=(combine(result,"s")+'\t')
    str_line+=(combine(result,"sc")+'\t')
    str_line+=(combine(result,"bf")+'\t')
    str_line+=(combine(result,"srn")+'\t')
    str_line+=(combine(result,"swh")+'\t')
    str_line+=(combine(result,"sht")+'\t')
    str_line+=(combine(result,"ctb")+'\t')
    str_line+=(combine(result,"mtb")+'\t')
    str_line+=(combine(result,"ct")+'\t')
    str_line+=(combine(result,"tv")+'\t')
    str_line+=(combine(result,"ldp")+'\t')
    str_line+=(combine(result,"vid")+'\t')
    str_line+=(combine(result,"sid")+'\t')
    str_line+=(combine(result,"uid")+'\n')

    w.write(str_line)
    line = r.readline()

r.close()
w.close()

#压缩过滤后的日志
cmd = "tar -czvf " + wfile + ".tgz" + " " + wfile
os.system(cmd)

#打印过滤后日志和压缩日志大小到脚本日志中
print rfile + ": size is " + str(os.path.getsize(rfile)/1024/1024) + "MB"
print wfile + ": size is " + str(os.path.getsize(wfile)/1024/1024) + "MB"
print wfile+".tgz" + ": size is " + str(os.path.getsize(wfile + ".tgz")/1024.0/1024.0) + "MB"

#删除过滤后日志和原始日志
cmd = "rm -rf " + wfile
os.system(cmd)

cmd = "rm -rf " + rfile
os.system(cmd)

print datetime.now().strftime("%Y-%m-%d-%H-%M") + ":  dsp.py end..."
