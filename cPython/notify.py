#!/usr/bin/env python
# encoding: utf-8

import os
from pyinotify import WatchManager, Notifier, ProcessEvent, IN_DELETE, IN_CREATE,IN_MODIFY,IN_CLOSE_WRITE

wm = WatchManager()
mask = IN_CREATE|IN_MODIFY|IN_CLOSE_WRITE

class PFilePath(ProcessEvent):
    def process_IN_CLOSE_WRITE(self, event):
        if event.name =='4913':
            pass
        else:
            print "Close writable file: %s " % os.path.join(event.path, event.name)
            filename = os.path.join(event.path, event.name)
            os.system("python test.py %s" % filename)

if __name__ == "__main__":
    notifier = Notifier(wm, PFilePath())
    wdd = wm.add_watch('.',mask,rec=True)

    while True:
        try:
            notifier.process_events()
            if notifier.check_events():
                notifier.read_events()
        except KeyboardInterrupt:
            notifier.stop()
            break

