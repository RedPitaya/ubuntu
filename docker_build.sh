#!/usr/bin/env bash
# Builds the image inside a throwaway Docker container and collects artifacts.

set -Eeuo pipefail

BUILD_NUM="${BUILD_NUMBER:-local}"
IMAGE_NAME="redpitaya-ubuntu-os-builder"
FULL_IMAGE_NAME="${IMAGE_NAME}:latest"
CONTAINER_NAME="rp-builder-${BUILD_NUM}"
ARTIFACT_DIR="$(pwd)/artifacts"

# Runs on every exit path, so a failed build never leaves the builder behind.
cleanup() {
    local rc=$?
    echo "=== cleanup: removing builder container and image"
    docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
    docker rmi -f "${FULL_IMAGE_NAME}" >/dev/null 2>&1 || true
    docker builder prune -f --filter type=frontend >/dev/null 2>&1 || true
    [ "$rc" -eq 0 ] || echo "=== build #${BUILD_NUM} FAILED (exit ${rc})"
    exit "$rc"
}
trap cleanup EXIT

echo "=== [1/4] cleaning previous run"
rm -rf "$ARTIFACT_DIR"
mkdir -p "$ARTIFACT_DIR"
if docker ps -a -q -f name="^${CONTAINER_NAME}$" | grep -q .; then
    docker logs "${CONTAINER_NAME}" > "${ARTIFACT_DIR}/previous_build_${BUILD_NUM}.log" 2>&1 || true
    docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
fi
docker rmi -f "${FULL_IMAGE_NAME}" >/dev/null 2>&1 || true
docker image prune -f >/dev/null 2>&1 || true

echo "=== [2/4] building builder image"
[ -f Dockerfile ] || { echo "Dockerfile not found" >&2; exit 1; }
docker build --no-cache --pull -t "${FULL_IMAGE_NAME}" .

echo "=== [3/4] running build #${BUILD_NUM}"
docker run --privileged --rm \
    --name "${CONTAINER_NAME}" \
    -v /dev:/dev \
    -v "${ARTIFACT_DIR}":/artifacts \
    -e BUILD_NUM="${BUILD_NUM}" \
    -e GIT_COMMIT="${GIT_COMMIT:-unknown}" \
    "${FULL_IMAGE_NAME}" /bin/bash -c '
        set -Eeuo pipefail
        [ -f /.dockerenv ] || { echo "not running inside a container" >&2; exit 1; }
        rc=0
        /build/build.sh || rc=$?
        for pattern in "*.zip" "*.tar.gz" "*.txt" "*.log"; do
            find /build/out -maxdepth 1 -type f -name "$pattern" \
                -exec cp -f {} /artifacts/ \; 2>/dev/null || true
        done
        exit $rc
    '

echo "=== [4/4] artifacts"
ls -lh "$ARTIFACT_DIR"
echo "=== build #${BUILD_NUM} completed"
