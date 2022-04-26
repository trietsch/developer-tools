#!/bin/env python3

import subprocess, json
from itertools import groupby

def toFloat(s):
    if type(s) is int: return float(s)
    if s.endswith("m"): return 0.001 * float(s[:-1])
    elif s.endswith("Gi"): return 1e9 * float(s[:-2])
    elif s.endswith("Mi"): return 1e6 * float(s[:-2])
    else: return float(s)

query="""{range .items[*]}{@.metadata.name}{"☆"}{@.metadata.ownerReferences}{"☆"}{@.spec.containers[*].resources.requests}{"\\n"}{end}"""
args = ["kubectl", "get", "pods", "-o=jsonpath="+query, "-A"]
data = subprocess.run(args, capture_output=True)
items = data.stdout.decode("utf-8").strip().split("\n")
pods = []
for i in items:
    name, owner, requests = i.strip().split("☆")
    owner = json.loads(owner) if owner else "unknown"
    if len(owner) == 1:
        owner = f"{owner[0]['kind']}-{owner[0]['name']}"
    requests = json.loads(f"[{','.join(requests.split(' '))}]")
    cpu = sum([toFloat(c.get('cpu',0)) for c in requests])
    pods.append(dict(
        cpu = cpu,
        name=name,
        owner = owner,
        requests = requests,
        ))


pods_with_cpu = sorted([pod for pod in pods if pod['cpu']], key=lambda pod: pod['cpu'],
    reverse=True)

print("total cpu requested %.2f" % sum([pod['cpu'] for pod in pods_with_cpu]))
for owner, pods in groupby(pods_with_cpu, key=lambda pod: pod['owner']):
    print("*"*10, owner, "*"*10)
    for pod in pods:
        print("%.2f %-70s %s" % (pod['cpu'], pod['name'], pod['requests']))
