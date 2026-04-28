# BuildKit overlayfs copy-up race reproduction

Minimal reproduction for a race condition where parallel Docker builds sharing
identical lower snapshots produce EACCES inside a `chmod 777` directory under
I/O pressure.

## The bug

Three Dockerfiles share byte-for-byte identical opening layers:

```dockerfile
FROM redhat/ubi10-minimal:10.1
RUN mkdir -p /app/.shared-dir && chmod 777 /app/.shared-dir
```

BuildKit deduplicates these into a single content-addressed snapshot used as
the read-only lower layer for all three parallel builds. When those builds
simultaneously write into `/app/.shared-dir`, the kernel must perform an
overlayfs copy-up for each container independently. Under concurrent I/O
pressure on slow storage (HDD), the copy-up races produce EACCES.

## Observed error

```
FATAL: mkdir('/app/.shared-dir/...'): (error: 13): Permission denied
```

The process is running as root. Unix permissions are not the cause.

## Reproduction

```bash
chmod +x repro.sh
./repro.sh --iterations 10
```

**Best reproduced on HDD-backed `/var/lib/docker`.** On NVMe the copy-up
completes fast enough that the race window rarely opens.

The script first primes the layer cache with a sequential build (so the shared
snapshot exists as a cached lower layer), then runs parallel builds repeatedly.
The failure requires the warm cache — a cold `--no-cache` build rarely fails
because all three snapshots are being written simultaneously rather than
referencing a pre-existing cached lower layer.

## Environment where consistently reproduced

- BuildKit: v0.29.0
- Driver: docker (snapshotter: overlayfs)
- Kernel: 6.12.0-124.49.1.el10_1.x86_64 (AlmaLinux 10)
- Storage: HDD-backed `/var/lib/docker`

## Workaround

Make the directory name unique per Dockerfile so BuildKit never deduplicates
the layers into a shared snapshot:

```dockerfile
# Dockerfile.a
RUN mkdir -p /app/.shared-dir-a && chmod 777 /app/.shared-dir-a

# Dockerfile.b
RUN mkdir -p /app/.shared-dir-b && chmod 777 /app/.shared-dir-b

# Dockerfile.c
RUN mkdir -p /app/.shared-dir-c && chmod 777 /app/.shared-dir-c
```

## Related

- moby/buildkit#4674 — same root cause (shared-vertex deduplication in
  concurrent solves), different symptom
