#!/bin/sh
set -e

apk add kubectl yq

echo ""
echo "Starting cleanup task..."

PODS_FILE="/tmp/pods.txt"
RUNNERS_FILE="/tmp/runners.txt"
DIFF_FILE="/tmp/runners_diff.txt"
NS="${namespace}"
SELECTOR="app.kubernetes.io/part-of=gha-runner-scale-set"

kubectl -n $NS get pods -l $SELECTOR -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' > $PODS_FILE
kubectl -n $NS get ephemeralrunners -o yaml | yq '.items[] | select(.status.phase == "Running") | .metadata.name' > $RUNNERS_FILE

## Subtract Pods from running EphemeralRunners to find runners that no longer have a pod
comm -13 <(sort $PODS_FILE) <(sort $RUNNERS_FILE) > $DIFF_FILE

echo "Runner pods: $(wc -l $PODS_FILE | awk -F' ' '{print $1}')"
echo "Ephemeral runners: $(wc -l $RUNNERS_FILE | awk -F' ' '{print $1}')"
echo "Found $(wc -l $DIFF_FILE | awk -F' ' '{print $1}') ephemeral runners without pods"

for runner in $(cat $DIFF_FILE); do
    kubectl -n $NS delete ephemeralrunner $runner
done
rm $PODS_FILE $RUNNERS_FILE $DIFF_FILE

echo "Done."
