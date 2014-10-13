#!/usr/bin/env python
# encoding: utf-8

import os
from pyinotify import WatchManager, Notifier, ProcessEvent, IN_DELETE, IN_CREATE,IN_MODIFY,IN_CLOSE_WRITE

path = "/opt/data/backup/exchange1.2/reportserver/bidinfo/log"
wm = WatchManager()
mask = IN_CLOSE_WRITE

class PFilePath(ProcessEvent):
    def process_IN_CLOSE_WRITE(self, event):
        if event.name =='4913':
            pass
        else:
            print "Close writable file: %s " % event.name
            filename = event.name
	    if (filename.find("express") == -1 and filename.endswith("bidinfo.log")):
                os.system("python bidinfo.py %s/%s" % (path,filename))

if __name__ == "__main__":
    notifier = Notifier(wm, PFilePath())
    wdd = wm.add_watch(path,mask,rec=True)

    while True:
        try:
            notifier.process_events()
            if notifier.check_events():
                notifier.read_events()
        except KeyboardInterrupt:
            notifier.stop()
            break

