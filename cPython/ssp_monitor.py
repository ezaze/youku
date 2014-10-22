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

    str=version+"\t"                #version
    str+=(combine(result,"bj")+'\t') #time
    str+=(combine(result,"s")+'\t') #ip
#dspid castid
    str+=(combine(result,"bf")+'\t')
#idea
    if combine(result,"be") == "":
        str+=(combine(result,"ci") + '\t')
    else:
        str+=(combine(result,"be")+'\t')
    str+=(combine(result,"sct")+'\t') #categoryid
    str+=(combine(result,"scs")+'\t') #subcategoryid
    str+=(combine(result,"sv")+'\t') #vid
    str+=(combine(result,"su")+'\t') #uid
#胜出平台id exchange 2
    str+=('2'+'\t')
    str+=(combine(result,"sck")+'\t')  #cookie
    str+=' \t'     #al
    str+=(combine(result,"bl")+'\t') #isLong
#节目id
    str+=(combine(result,"ss")+'\t')
#正本视频vid
    str+=(combine(result,"std")+'\t')
    str+=' \t' #vl
    str+=(combine(result,"sat")+'\t') #adposition
    str+=' \t' #sessionid
    str+=(combine(result,"scr")+'\t') #copyright
    str+=' \t'  #orderid
#exclusive package type
    str+=(combine(result,"sprd")+'\t')
#product type
    str+=' \t'
    str+=' \t' #avs
    str+=' \t' #dp
    str+=' \t' #device_type
    str+=' \t' #os_type
    str+=' \t' #clitent_type
    str+=' \t' #sdkid
    str+=' \t' #offad
    str+=(combine(result,"suri")+'\t') #loginid
    str+=' \t' #reserved1 >dcid
    str+=' \t' #reserved2
    str+=' \t' #reserved3
    str+=' \t' #reserved4
    str+=' \t' #ext
    str+=' \t' #hyid
    str+=(combine(result,"spc")+'\t') #price
    str+=(combine(result,"slog")+'\n') #logtype

   #test
    if combine(result,"slog")=="":
        print "slog = ''"
    elif int(combine(result,"slog"))%2 == 1:
        youku.write(str)
    else:
        tudou.write(str)
r.close()
youku.close()
tudou.close()
