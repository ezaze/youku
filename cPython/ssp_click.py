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

    str=version+"\t"                //version
    str+=(combine(result,"bj")+'\t') //time
    str+=(combine(result,"s")+'\t') //ip
    str+=(combine(result,"bf")+'\t') //dspid castid
    if combine(result,"be") == "":  //idea
        str+=(combine(result,"ci") + '\t')
    else:
        str+=(combine(result,"be")+'\t')
    str+=(combine(result,"sct")+'\t') //categoryid
    str+=(combine(result,"scs")+'\t') //subcategoryid
    str+=(combine(result,"sv")+'\t') //vid
    str+=(combine(result,"su")+'\t') //uid
    str+=('2'+'\t')  //胜出平台id exchange 2
    str+=(combine(result,"sck")+'\t')  //cookie
    str+=' \t'     //al
    str+=(combine(result,"bl")+'\t') //isLong
    str+=(combine(result,"ss")+'\t') //节目id
    str+=(combine(result,"std")+'\t') //正本视频vid
    str+=' \t' //vl
    str+=(combine(result,"sat")+'\t') //adposition
    str+=' \t' //sessionid
    str+=(combine(result,"scr")+'\t') //copyright
    str+=' \t'  //orderid
    str+=(combine(result,"sprd")+'\t') //exclusive package type
    str+=' \t' //product type
    str+=' \t' //avs
    str+=' \t' //dp
    str+=' \t' //device type
    str+=' \t' //os type
    str+=' \t' //clitent type
    str+=' \t' //sdkid
    str+=' \t' //offad
    str+=(combine(result,"suri")+'\t') //loginid
    str+=' \t' //reserved1 >dcid
    str+=' \t' //reserved2
    str+=' \t' //reserved3
    str+=' \t' //reserved4
    str+=' \t' //ext
    str+=' \t' //hyid
    str+=(combine(result,"spc")+'\t') //price
    str+=(combine(result,"slog")+'\n') //logtype

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
