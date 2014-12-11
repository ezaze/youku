#!/usr/bin/env python
# encoding: utf-8

import smtplib

server = smtplib.SMTP()
server.connect("smtp.163.com")
server.login("15011094157@163.com","youku123")

fromaddr="From:15011094157@163.com"
toaddr="To:15011094157@163.com"

msg='''Subject: Something wrong with exchange log process '''


server.sendmail(fromaddr, toaddr, msg)
server.quit()


