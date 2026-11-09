#!/usr/bin/env python3
"""Set the Argo CD admin password unless it already matches.

Reads the password from ARGOCD_PASSWORD and the kubeconfig from KUBECONFIG.
Prints "changed" or "unchanged".
"""
import base64
import datetime
import json
import os
import subprocess
import sys

import bcrypt

password = os.environ["ARGOCD_PASSWORD"].encode()
kubectl = ["kubectl", "-n", "argocd"]

secret = json.loads(subprocess.run(kubectl + ["get", "secret", "argocd-secret", "-o", "json"], check=True, capture_output=True, text=True).stdout)
current = base64.b64decode(secret.get("data", {}).get("admin.password", "")) if secret.get("data", {}).get("admin.password") else b""

if current and bcrypt.checkpw(password, current):
    print("unchanged")
    sys.exit(0)

hashed = bcrypt.hashpw(password, bcrypt.gensalt(rounds=10)).decode()
mtime = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
patch = json.dumps({"stringData": {"admin.password": hashed, "admin.passwordMtime": mtime}})
subprocess.run(kubectl + ["patch", "secret", "argocd-secret", "--type", "merge", "-p", patch], check=True, capture_output=True)
print("changed")
