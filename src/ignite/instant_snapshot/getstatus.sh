#!/usr/bin/env bash
set -euo pipefail

INTERVAL=10
SNAP_ID="/subscriptions/078593a1-d730-4656-9e5a-788d6717bb52/resourceGroups/instant-snapshot/providers/Microsoft.Compute/snapshots/ultradisksnapshot"

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
