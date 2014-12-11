#!/usr/bin/env python
# encoding: utf-8
from datetime import *
from datetime import timedelta
import os

now = datetime.today()
ago = now + timedelta(-1)
atmApi="http://adm.youku.com/getRtbIdeaUrl.sdo?pageNo=1&pageSize=2002&startTime=%s&endTime=%s"%(ago.strftime("%Y%m%d000000"),now.strftime("%Y%m%d235959"))
cmd = 'curl  "%s">1' % atmApi
os.system(cmd)

f=open('1')
result = f.readline()
results=result.split("},")

urls=list()

for index in range(len(results)):
    dspid_start=results[index].find("dspId")+8
    status_start=results[index].find("status")+8
    status_end=results[index].find("url")-2
    if results[index][status_start:status_end] =="1" and results[index][dspid_start:dspid_start+5] == "11142":
        url_start=results[index].find("url")+5
        url_end=results[index].find("dspId")-2
        urls.append(results[index][url_start:url_end].replace("\\u003a",":").replace("\\u002e","."))


for url in urls:
    #com = 'curl -i -H "Content-Type: application/json" -d \'{"dspid":"11142","token":"3f9a0e0d57c04abd83ed9c4071e9b641","material":[{"url":"%s","landingpage":"www.youku.com","advertiser":"淘宝","startdate":"2014-01-01","enddate":"2015-09-01"}]}\' \'http://miaozhen.atm.youku.com/dsp/api/upload\'' %(url.strip())
    com = 'curl -i -H "Content-Type: application/json" -d \'{"dspid":"11142","token":"3f9a0e0d57c04abd83ed9c4071e9b641""material":[{"url":"%s","landingpage":"www.youku.com","advertiser":"淘宝","startdate":"2014-01-01","enddate":"2015-09-01"}]}\' \'http://miaozhen.atm.youku.com/dsp/api/upload\'' %(url.strip())
    os.system(com)

update_sql="mysql -uroot -psunbx bazaro -e 'update material set Duration=15,Width=640,Height=400,Status=2 where dspId='11142'"
os.system(update_sql)
