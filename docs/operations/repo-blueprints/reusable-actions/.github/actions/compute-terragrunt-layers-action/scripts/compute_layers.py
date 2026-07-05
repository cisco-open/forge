#!/usr/bin/env python3
import json
import os
import re
import sys
from collections import defaultdict

dot = sys.stdin.read() if not sys.stdin.isatty() else open(sys.argv[1]).read()

edges = re.findall(r'"([^"]+)"\s*->\s*"([^"]+)"', dot)

nodes = list(dict.fromkeys(re.findall(r'"([^"]+)"', dot)))

graph = defaultdict(list)
indegree = {n: 0 for n in nodes}
for src, dst in edges:
    graph[src].append(dst)
    indegree[dst] += 1

layers = []
processed = set()

while True:

    layer = [n for n in nodes if indegree[n] == 0 and n not in processed]
    if not layer:
        break
    layers.append(layer)
    for node in layer:
        processed.add(node)
        for dep in graph[node]:
            indegree[dep] -= 1

unprocessed = [n for n in nodes if n not in processed]
if unprocessed:
    print('Warning: cycle detected:', unprocessed, file=sys.stderr)

layers.reverse()

tf_path = os.environ.get('TF_PATH', '').rstrip('/\n')


def to_name_and_path(node_label: str):
    raw = node_label.strip()
    # Determine full path by merging TF_PATH and the DAG-provided path when appropriate
    if tf_path:
        if os.path.isabs(raw):
            full_path = os.path.normpath(raw)
        else:
            full_path = os.path.normpath(os.path.join(tf_path, raw))
    else:
        full_path = raw

    # Build a friendly name from path segments: a/b/c -> a - b - c
    normalized = re.sub(r'/+', '/', raw.strip('/'))
    parts = [p for p in normalized.split('/') if p and p != '.']
    if parts:
        name = ' - '.join(parts)
    else:
        # Fallback to basename if splitting fails
        name = os.path.basename(full_path.rstrip('/')) or raw
    return {'name': name, 'path': full_path}


output_layers = [[to_name_and_path(n) for n in layer] for layer in layers]

print(json.dumps(output_layers, indent=2))
