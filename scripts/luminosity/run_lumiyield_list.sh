#!/bin/bash

RUNLIST="$1"
ROOTPREFIX="PionLT_replay_luminosity"
MAXEVENTS="-1"

if [[ -z "$RUNLIST" ]]; then
    echo "Usage: ./run_lumiyield_list.sh /full/path/to/runlist.txt"
    exit 2
fi

if [[ ! -f "$RUNLIST" ]]; then
    echo "ERROR: run list not found: $RUNLIST"
    exit 3
fi

cd "/group/c-pionlt/USERS/${USER}/hallc_replay_lt/UTIL_PION/scripts/luminosity/src" || exit 4

while read -r RUNNUMBER; do
    [[ -z "$RUNNUMBER" ]] && continue
    [[ "$RUNNUMBER" =~ ^# ]] && continue

    echo "======================================"
    echo "Running lumiyield.py for ${RUNNUMBER}"
    echo "======================================"

    python3 lumiyield.py "$ROOTPREFIX" "$RUNNUMBER" "$MAXEVENTS"

done < "$RUNLIST"