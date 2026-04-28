FROM redhat/ubi10-minimal:10.1

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Identical layer across all three Dockerfiles — BuildKit deduplicates this
# into a single read-only snapshot shared by all parallel builds.
RUN mkdir -p /app/.shared-dir && chmod 777 /app/.shared-dir

RUN for i in $(seq 1 8); do \
        mkdir -p /app/.shared-dir/sub-$i && \
        dd if=/dev/urandom of=/app/.shared-dir/sub-$i/data bs=1M count=16 & \
    done; wait
