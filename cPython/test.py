#!/usr/bin/env python
# encoding: utf-8

#rfile="201409181353-exchange-a04-cn-reportserver-click.log"
rfile="a.log"
wyouku=rfile[:-4]+"youku.log"
wtudou=rfile[:-4]+"tudou.log"

r=open(rfile)
youku=open(wyouku,'w')
tudou=open(wtudou,'w')


version="7"
def combine(dict,str):
    try:
        tmp=dict[str]
        return tmp
    except KeyError:
        return ""


for line in r.readlines():
    result=dict()
    query=line[line.find('?')+1:-1]
    parts=query.split('&')
    for part in parts:
        result[part.split('=')[0]]=part.split('=')[1]
    print combine(result,"slog")
r.close()
youku.close()
tudou.close()
