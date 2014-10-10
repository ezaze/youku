#!/usr/bin/env python
# encoding: utf-8

rfile="201409151609-exchange-a05-cn-reportserver-auction.log"
wfile=rfile[:-4]+"-express.log"

r=open(rfile)
w=open(wfile,'w')


for line in r.readlines():
    parts=line.split('^')
    dsp_all=parts[15].split('|')
    dsp_result=""
    for dsp in dsp_all:
        dsp_part=dsp.split(";")
        dsp_result+=dsp_part[0]+';'+dsp_part[1]+';'+dsp_part[2]+';'+dsp_part[3]+'|'
    dsp_result=dsp_result[:-1]

    w.write(parts[6]+'\t'+parts[4]+'\t'+parts[7]+'\t'+parts[8]+'\t'+parts[9]+'\t'+dsp_result+'\n')
