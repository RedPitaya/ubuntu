#!/usr/bin/env bash

# Stop the script immediately if any command fails
set -e

# Get the build number from Jenkins, default to "local" if run outside Jenkins
BUILD_NUM="${BUILD_NUMBER:-local}"

# Docker image configuration
IMAGE_NAME="redpitaya-ubuntu-os-builder"
TAG="latest"
FULL_IMAGE_NAME="${IMAGE_NAME}:${TAG}"
CONTAINER_NAME="rp-builder-${BUILD_NUM}"

echo "=== [1/5] Aggressive Docker Cache & Old Image Cleanup ==="

# Remove existing builder image to force a completely clean rebuild
if docker images -q "${FULL_IMAGE_NAME}" > /dev/null 2>&1; then
    docker rmi -f "${FULL_IMAGE_NAME}" || true
fi
# Remove any leftover containers from previous runs
docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true

# Prune all dangling builder cache fragments and unused layers on the host system
echo "Pruning dangling Docker build cache layers..."
docker builder prune -f --filter type=frontend || true
docker image prune -f || true

echo "=== [2/5] Building Docker Image with ALL Source Code Inside ==="
if [[ ! -f "Dockerfile" ]]; then
    echo "Error: Dockerfile not found!"
    exit 1
fi

# Build with --no-cache for a fresh build, --pull for latest base image updates
# The Dockerfile COPY instruction bakes all source code into the image
docker build --no-cache --pull -t "${FULL_IMAGE_NAME}" .

echo "=== [3/5] Preparing Clean Artifacts Directory ==="
# Clean local artifacts directory only — no source code will be shared with the container
rm -rf artifacts
mkdir -p artifacts

echo "=== [4/5] Starting Fully Isolated Build Inside Container ==="
echo "Current build number: #${BUILD_NUM}"

# Run the build in an isolated container
# Only /dev (for loop devices) and artifacts directory are mounted
# Source code is NOT mounted from host — it's already inside the image via COPY
docker run --privileged --rm \
    --name "${CONTAINER_NAME}" \
    -v /dev:/dev \
    -v "$(pwd)/artifacts":/artifacts \
    -e BUILD_NUM="${BUILD_NUM}" \
    -e GIT_COMMIT="${GIT_COMMIT}" \
    "${FULL_IMAGE_NAME}" /bin/bash -c "

        # Verify we are running inside the Docker container, not on the host
        echo '=== Isolation Verification ==='
        if [ -f /.dockerenv ]; then
            echo 'SUCCESS: Running inside the Docker container'
        else
            echo 'ERROR: Leak detected! Running on host machine instead of container!'
            exit 1
        fi

        echo '=== Starting Red Pitaya Build ==='
        echo 'Source code location: /build (baked into image, NOT mounted from host)'
        ls -l /build/build.sh

        # Execute the main Red Pitaya build script from inside the container
        /build/build.sh

        echo '=== Artifact Filtering: Extracting tar.gz and zip files ==='

        # Find and copy all .tar.gz and .zip artifacts, rename with build number
        find /build -maxdepth 3 -type f \( -name '*.tar.gz' -o -name '*.zip' \) | while read -r file; do
            filename=\$(basename \"\$file\")

            # Handle double extension for .tar.gz files
            if [[ \"\$filename\" == *.tar.gz ]]; then
                base=\"\${filename%.tar.gz}\"
                ext='tar.gz'
            else
                base=\"\${filename%.*}\"
                ext='zip'
            fi

            new_name=\"\${base}-b\${BUILD_NUM}.\${ext}\"
            echo \"  Copying: \$filename -> artifacts/\$new_name\"
            cp \"\$file\" \"/artifacts/\$new_name\"
        done

        echo '=== Build completed successfully ==='
    "

echo "=== [5/5] Post-Build Cleanup ==="
# Remove the builder image to free up disk space on the Jenkins node
echo "Removing the builder image to keep the environment clean..."
docker rmi -f "${FULL_IMAGE_NAME}" || true

# Final cleanup of any residual Docker build cache
docker builder prune -f --filter type=frontend || true

echo "=== Build #${BUILD_NUM} completed successfully! ==="
echo "Saved files in artifacts/ directory:"
ls -lh artifacts/