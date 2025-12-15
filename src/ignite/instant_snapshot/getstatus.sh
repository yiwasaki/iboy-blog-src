#!/usr/bin/env bash
set -euo pipefail

INTERVAL=10
SNAP_ID="/subscriptions/***subscription id***/resourceGroups/instant-snapshot/providers/Microsoft.Compute/snapshots/ultradisksnapshot"

while true; do
  state=$(az resource show --ids "$SNAP_ID" --query "properties.snapshotAccessState" -o tsv)
  date
  echo "$state"
  if [[ "$state" != "Pending" ]]; then
    echo "Snapshot state is $state; exiting."
    break
  fi
  sleep "$INTERVAL"
done
