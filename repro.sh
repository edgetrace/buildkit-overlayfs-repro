#!/usr/bin/env bash
set -euo pipefail

# Reproduction script for BuildKit overlayfs copy-up race.
#
# Run this on a host with HDD-backed /var/lib/docker for best chance of
# reproduction. On NVMe the race window may be too narrow to hit reliably.
#
# Usage: ./repro.sh [--iterations N]
#
# Each iteration:
#   1. Primes the layer cache with a single sequential build (so the shared
#      snapshot exists as a cached lower layer on the next parallel run)
#   2. Runs all three builds in parallel via docker buildx bake
#   3. Reports pass/fail

ITERATIONS=${1:-5}
PASS=0
FAIL=0

echo "=== Priming layer cache (sequential build) ==="
docker buildx bake -f docker-bake.hcl --no-cache --progress=plain 2>&1 | tail -5

echo ""
echo "=== Running $ITERATIONS parallel iterations (with layer cache) ==="

for i in $(seq 1 "$ITERATIONS"); do
    echo -n "Iteration $i ... "
    if docker buildx bake -f docker-bake.hcl --progress=plain > /tmp/repro-iter-$i.log 2>&1; then
        echo "PASS"
        PASS=$((PASS + 1))
    else
        echo "FAIL"
        FAIL=$((FAIL + 1))
        grep -E "Permission denied|EACCES|error" /tmp/repro-iter-$i.log | head -5
    fi
done

echo ""
echo "=== Results: $PASS pass, $FAIL fail out of $ITERATIONS ==="
