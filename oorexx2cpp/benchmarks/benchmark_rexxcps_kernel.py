#!/usr/bin/env python3
"""Repeat the small source-derived kernel benchmark. NOT full RexxCPS."""
import os, subprocess, time, statistics, json, hashlib, pathlib
root = pathlib.Path(__file__).resolve().parent.parent
build = pathlib.Path(os.environ.get('BUILD', str(root / 'build/rexxcps-progress')))
source = root/'examples/rexxcps_loop_kernel.rex'
rexx = os.environ.get('REXX_BIN', 'rexx')
env = dict(os.environ)
if env.get('REXX_LIB'):
    env['LD_LIBRARY_PATH'] = env['REXX_LIB'] + ':' + env.get('LD_LIBRARY_PATH', '')
cmds = {'ooRexx':[rexx, str(source)], 'native':[str(build/'rexxcps_loop_kernel.native')]}
rounds = int(os.environ.get('RUNS', '7'))
records = []
for command in cmds.values():
    subprocess.run(command,env=env,check=True,capture_output=True,timeout=60)
for i in range(rounds):
    order = ('ooRexx', 'native') if i % 2 == 0 else ('native', 'ooRexx')
    for label in order:
        t0 = time.perf_counter()
        proc = subprocess.run(cmds[label], env=env, check=True, capture_output=True, timeout=60)
        elapsed = time.perf_counter()-t0
        if proc.stdout != b'500500000\n':
            raise RuntimeError(f'Unexpected {label} output; benchmark invalid: {proc.stdout!r}')
        records.append({'run':i+1,'target':label,'wall_seconds':round(elapsed,6),
                        'exit':proc.returncode, 'output_sha256':hashlib.sha256(proc.stdout).hexdigest()})
summary = {label:{'median_seconds':round(statistics.median(r['wall_seconds'] for r in records if r['target']==label),6),
                  'mean_seconds':round(statistics.mean(r['wall_seconds'] for r in records if r['target']==label),6)}
           for label in cmds}
summary['speedup_median'] = round(summary['ooRexx']['median_seconds']/summary['native']['median_seconds'],3)
print(json.dumps({'summary':summary,'runs':records},indent=2))
