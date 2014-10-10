#!/usr/bin/env python
# encoding: utf-8

rfile="201409181353-exchange-a04-cn-reportserver-click.log"
wfile=rfile[:-4]+"-express.log"

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
        result[part.split('=')[0]]=part.split('=')[1]

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
