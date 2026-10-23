#!/usr/bin/env python3
"""End-to-end Qt6 widget protocol qualification (offscreen or live).
Uses the actual Qt executable; no simulated widget implementation.
"""
import argparse
import json
import os
import queue
import subprocess
import sys
import threading
import time
from pathlib import Path

p = argparse.ArgumentParser()
p.add_argument('--executable', required=True)
p.add_argument('--fixture', required=True)
p.add_argument('--timeout', type=float, default=8)
p.add_argument('--trace', default=None)
a = p.parse_args()
env = os.environ.copy()
env.setdefault('QT_QPA_PLATFORM', 'offscreen')
proc = subprocess.Popen([a.executable,a.fixture],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE, text=True,bufsize=1,env=env)
q = queue.Queue()
trace = []
backlog = []
def reader():
    for line in proc.stdout:
        try: obj=json.loads(line)
        except ValueError: obj={'type':'malformed','line':line}
        trace.append(obj)
        q.put(obj)
threading.Thread(target=reader,daemon=True).start()
def await_packet(predicate, reason):
    for i, x in enumerate(backlog):
        if predicate(x):return backlog.pop(i)
    deadline=time.monotonic()+a.timeout
    while time.monotonic()<deadline:
        try: x=q.get(timeout=max(.01,deadline-time.monotonic()))
        except queue.Empty: break
        if x.get('type')=='error': raise AssertionError(f'{reason}: renderer error {x}')
        if predicate(x):return x
        backlog.append(x)
    raise AssertionError('timeout waiting for '+reason)
def cmd(action, cid=None, value=None):
    req={'action':action}
    if cid is not None:req['id']=cid
    if value is not None:req['value']=value
    proc.stdin.write(json.dumps(req)+'\n');proc.stdin.flush()
    return await_packet(lambda x:x.get('type')=='ack' and x.get('action')==action and x.get('id')==cid if cid is not None else x.get('type')=='ack' and x.get('action')==action, str(req))
def state(cid):
    proc.stdin.write(json.dumps({'action':'inspect','id':cid})+'\n');proc.stdin.flush()
    return await_packet(lambda x:x.get('type')=='state' and x.get('id')==cid,'inspect '+str(cid))
try:
    ready=await_packet(lambda x:x.get('type')=='ready','ready')
    assert ready['controls']>=9, ready
    # Values taken from the dev6 resource fixture IDs; validate rather than assume implementation.
    fixture=json.loads(Path(a.fixture).read_text())
    ctrls={}
    for res in fixture['resources']:
        if str(res.get('type',res.get('resourceType',''))).upper().startswith('DIALOG'):
            for e in res.get('entries',[]):
                if e.get('kind')=='control':
                    args=e['arguments']; ct=e['controlType'].upper()
                    rid=e.get('resolvedControlId')
                    if rid is None:
                        off=1 if ct in {'PUSHBUTTON','DEFPUSHBUTTON','LTEXT','CHECKBOX','AUTOCHECKBOX','RADIOBUTTON','AUTORADIOBUTTON','GROUPBOX','RTEXT','CTEXT'} else 0
                        rid=args[off]
                    ctrls[ct]=int(rid)
    button=next((v for k,v in ctrls.items() if k in {'PUSHBUTTON','DEFPUSHBUTTON'}),None)
    edit=ctrls.get('EDITTEXT')
    assert button is not None and edit is not None,ctrls
    cmd('setText',edit,'dev7 protocol test')
    assert state(edit)['text']=='dev7 protocol test'
    cmd('activate',button)
    await_packet(lambda x:x.get('type')=='event' and x.get('id')==button and x.get('event')=='click','button click event')
    if 'LISTBOX' in ctrls:
        cid=ctrls['LISTBOX'];cmd('addItem',cid,'alpha');cmd('addItem',cid,'beta');cmd('select',cid,1)
        assert state(cid)['selection']==1
    if 'COMBOBOX' in ctrls:
        cid=ctrls['COMBOBOX'];cmd('addItem',cid,'one');cmd('addItem',cid,'two');cmd('select',cid,1)
        assert state(cid)['selection']==1
    if 'AUTOCHECKBOX' in ctrls:
        cid=ctrls['AUTOCHECKBOX'];cmd('setValue',cid,True)
        assert state(cid)['checked'] is True
    if 'PROGRESSBAR' in ctrls:
        cid=ctrls['PROGRESSBAR'];cmd('setValue',cid,42)
        assert state(cid)['value']==42
    proc.stdin.write('{"action":"quit"}\n');proc.stdin.flush()
    proc.wait(timeout=a.timeout)
    assert proc.returncode==0,proc.returncode
    print('PASS Qt6 protocol: ready, text, click event, collection selection, state')
except Exception as e:
    print('FAIL Qt6 protocol:',e,file=sys.stderr)
    print('stderr:',proc.stderr.read() if proc.poll() is not None else '(process still active)',file=sys.stderr)
    sys.exit(1)
finally:
    if a.trace:Path(a.trace).write_text('\n'.join(json.dumps(x,sort_keys=True) for x in trace)+'\n')
    if proc.poll() is None:proc.kill();proc.wait()