#!/bin/bash
# Container start script for a Pod and for a serverless worker.
#   Pod:        start sshd, then keep the container running.
#   Serverless: start sshd (if PUBLIC_KEY is set), then run the job handler.
# Runpod sets RUNPOD_ENDPOINT_ID only on serverless workers. Set MFLUX_MODE=pod|serverless to override.
set -e

MODE="${MFLUX_MODE:-$([ -n "$RUNPOD_ENDPOINT_ID" ] && echo serverless || echo pod)}"
echo "mode: $MODE"

# Keep the Hugging Face cache on the volume: /runpod-volume (network volume) or /workspace (pod volume).
if [ -z "$HF_HOME" ]; then
    for dir in /runpod-volume /workspace; do
        if [ -d "$dir" ]; then export HF_HOME="$dir/hf"; break; fi
    done
fi

# Runpod sets PUBLIC_KEY to the SSH public keys of the account.
if [ -n "$PUBLIC_KEY" ]; then
    mkdir -p /root/.ssh
    chmod 700 /root/.ssh
    echo "$PUBLIC_KEY" >> /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
    ssh-keygen -A
    mkdir -p /run/sshd
    /usr/sbin/sshd
    echo "sshd started"
else
    echo "PUBLIC_KEY is not set: sshd not started. Add an SSH key to the Runpod account."
fi

# SSH sessions do not get the container environment. Save it, and load it in each login shell.
export -p | grep -E ' (PATH|LD_LIBRARY_PATH|HF_[A-Z_]*|MFLUX_[A-Z_]*|RUNPOD_[A-Z_]*|PYTHONUNBUFFERED)=' > /etc/rp_environment || true
grep -q rp_environment /root/.bashrc 2>/dev/null || echo 'source /etc/rp_environment' >> /root/.bashrc

if [ "$MODE" = "serverless" ]; then
    exec python -u /app/handler.py
else
    exec sleep infinity
fi
