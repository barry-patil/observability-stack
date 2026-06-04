# Runbook: PodCrashLooping

**Alert:** `PodCrashLooping`  
**Severity:** Warning  
**Fires when:** A pod restarts more than once in any 15-minute window, sustained for 5 minutes

## What's probably happening

The three most common causes I've seen:

1. Application error on startup (bad config, missing env var, failed DB connection)
2. OOMKill — the container hit its memory limit and was killed
3. Liveness probe failing — the app starts but the probe endpoint isn't responding fast enough

## Steps

**1. Check recent pod events**
```bash
kubectl describe pod <pod-name> -n <namespace>
```
Look at the Events section at the bottom. "Back-off restarting failed container" is normal for crash loops. The exit code and reason matter more.

**2. Pull the logs from the previous container run**
```bash
kubectl logs <pod-name> -n <namespace> --previous
```
If the pod is restarting too fast, you won't get logs from the current run — `--previous` gets you the last completed container.

**3. Check for OOMKill**
```bash
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.status.containerStatuses[*].lastState.terminated}'
```
If `reason` is `OOMKilled`, the fix is increasing the memory limit in the deployment spec. Don't just bump it blindly — check whether there's an actual memory leak first.

**4. Check the liveness probe**
```bash
kubectl get deployment <deployment-name> -n <namespace> -o yaml | grep -A 15 livenessProbe
```
If `initialDelaySeconds` is too low and the app takes time to start, the probe will kill it before it's ready. Increase `initialDelaySeconds` or switch to a startup probe.

**5. If it's a config issue**
```bash
kubectl get configmap -n <namespace>
kubectl get secret -n <namespace>
```
Check that all expected config maps and secrets exist. A missing secret reference will cause the pod to fail at startup with a descriptive error in the logs.

## Escalation

If the pod keeps crashing after trying the above and the logs don't point to an obvious cause, escalate to the service owner. Provide: pod name, namespace, exit code, last 50 lines of `--previous` logs.
