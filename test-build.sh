#!/bin/bash
# Test script for rootless container builds with Podman
# This simulates the unprivileged ROSA environment

echo "=== Rootless Build Test Script ==="
echo "Testing container builds in unprivileged mode similar to ROSA"
echo ""

# Set environment for rootless operation
export STORAGE_DRIVER=vfs
export BUILDAH_ISOLATION=chroot

# Show current user context
echo "Current user: $(whoami)"
echo "UID: $(id -u)"
echo "GID: $(id -g)"
echo ""

# Test 1: Basic podman build with VFS storage driver
echo "Test 1: Basic rootless build with VFS driver"
echo "==========================================="
podman build \
  --storage-driver=vfs \
  --format=oci \
  --no-cache \
  -t test-rootless:basic \
  -f Dockerfile \
  . 2>&1 | tee build-basic.log

echo ""
echo "Test 2: Build with explicit rootless settings"
echo "============================================="
podman build \
  --storage-driver=vfs \
  --isolation=chroot \
  --userns-uid-map-user=$(whoami) \
  --no-cache \
  -t test-rootless:explicit \
  -f Dockerfile \
  . 2>&1 | tee build-explicit.log

echo ""
echo "Test 3: Build with security options similar to ROSA"
echo "=================================================="
podman build \
  --storage-driver=vfs \
  --cap-drop=ALL \
  --security-opt=no-new-privileges \
  --no-cache \
  -t test-rootless:secure \
  -f Dockerfile \
  . 2>&1 | tee build-secure.log

# Test running the container
echo ""
echo "Test 4: Run container in rootless mode"
echo "======================================"
podman run \
  --rm \
  --userns=keep-id \
  --security-opt=no-new-privileges \
  --cap-drop=ALL \
  --cap-add=NET_BIND_SERVICE \
  -p 8080:8080 \
  --name test-rootless-run \
  test-rootless:basic \
  python3 app.py &

CONTAINER_PID=$!
sleep 5

# Test the running container
echo "Testing container endpoint..."
curl -s http://localhost:8080 || echo "Failed to connect"

# Clean up
echo ""
echo "Cleaning up..."
podman stop test-rootless-run 2>/dev/null || true
kill $CONTAINER_PID 2>/dev/null || true

# Show images built
echo ""
echo "Built images:"
podman images | grep test-rootless

# Test with buildah directly (if available)
if command -v buildah &> /dev/null; then
    echo ""
    echo "Test 5: Direct buildah test"
    echo "==========================="
    buildah --storage-driver=vfs bud \
      --format=oci \
      --isolation=chroot \
      --no-cache \
      -t test-rootless:buildah \
      -f Dockerfile \
      .
fi

echo ""
echo "=== Build Test Summary ==="
echo "Check the following log files for details:"
echo "- build-basic.log"
echo "- build-explicit.log" 
echo "- build-secure.log"
