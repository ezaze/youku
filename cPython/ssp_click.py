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

    str=version+"\t"
    str+=(combine(result,"bj")+'\t')
    str+=(combine(result,"s")+'\t')
    str+=' \t'
    if combine(result,"be") == "":
        str+=(combine(result,"ci") + '\t')
    else:
        str+=(combine(result,"be")+'\t')
    str+=(combine(result,"sct")+'\t')
    str+=(combine(result,"scs")+'\t')
    str+=(combine(result,"sv")+'\t')
    str+=(combine(result,"su")+'\t')
    str+=('2'+'\t')
    str+=(combine(result,"sck")+'\t')
    str+=' \t'
    str+=(combine(result,"bl")+'\t')
    str+=(combine(result,"ss")+'\t')
    str+=(combine(result,"std")+'\t')
    str+=' \t'
    str+=(combine(result,"sat")+'\t')
    str+=' \t'
    str+=(combine(result,"scr")+'\t')
    str+=' \t'
    str+=(combine(result,"sprd")+'\t')
    str+=' \t'
    str+=' \t'
    str+=' \t'
    str+=' \t'
    str+=' \t'
    str+=' \t'
    str+=' \t'
    str+=' \t'
    str+=(combine(result,"suri")+'\t')
    str+=' \t'
    str+=' \t'
    str+=' \t'
    str+=' \t'
    str+=' \t'
    str+=(combine(result,"spc")+'\t')
    str+=(combine(result,"slog")+'\n')
   
   #test
    if combine(result,"slog")=="":
        i+=1
    elif int(combine(result,"slog"))%2 == 1:
        youku.write(str)
    else:
        tudou.write(str)
r.close()
youku.close()
tudou.close()
