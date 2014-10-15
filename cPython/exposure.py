#!/usr/bin/env python
# encoding: utf-8
import sys,os
try:
    rfile = sys.argv[1]
except:
    os.system("python sendmail.py")
wfile = rfile[:-4].replace('log','express_log') +"-express.log"

r=open(rfile)
w=open(wfile,'w')

def combine(dict,str):
    try:
        tmp=dict[str]
        return tmp
    except KeyError:
        return ""


result=dict()
for line in r.readlines():
    query=line[line.find('?')+1:-1]
    parts=query.split('&')
    for part in parts:
        try:
            result[part.split('=')[0]]=part.split('=')[1]
        except:
            pass

    str=""
    str+=(combine(result,"bb")+'\t')
    str+=(combine(result,"l")+'\t')
    str+=(combine(result,"ba")+'\t')
    str+=(combine(result,"usr")+'\t')
    str+=(combine(result,"bf")+'\t')
    str+=(combine(result,"be")+'\t')
    str+=(combine(result,"s")+'\t')
    str+=(combine(result,"bj")+'\t')
    str+=(combine(result,"bd")+'\t')
    str+=(combine(result,"bq")+'\t')
    str+=(combine(result,"aw")+'\t')
    str+=(combine(result,"dt")+'\t')
    str+=(combine(result,"os")+'\t')
    str+=(combine(result,"n")+'\t')
    str+=(combine(result,"vid")+'\n')

    w.write(str)

r.close()
w.close()
