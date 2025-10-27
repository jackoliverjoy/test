#!/bin/bash
# Buildah Debug Pipeline Script

echo "========================================"
echo "BUILDAH DEBUG PIPELINE - START"
echo "========================================"
echo ""

# 1. System Information
echo "=== SYSTEM INFORMATION ==="
echo "Hostname: $(hostname)"
echo "Kernel: $(uname -r)"
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo "Date: $(date)"
echo ""

# 2. User Information
echo "=== USER INFORMATION ==="
echo "Current user: $(whoami)"
echo "User ID: $(id -u)"
echo "Group ID: $(id -g)"
echo "All groups: $(groups)"
echo "Home directory: $HOME"
echo ""

# 3. Process Information
echo "=== PROCESS INFORMATION ==="
echo "Process tree:"
ps auxf | grep -E "($$|buildah)" | grep -v grep
echo ""
echo "Parent PID: $PPID"
echo "Current PID: $$"
echo ""

# 4. Buildah Information
echo "=== BUILDAH INFORMATION ==="
which buildah && echo "Buildah path: $(which buildah)"
buildah version || echo "Failed to get buildah version"
echo ""
echo "Buildah info:"
buildah info 2>&1 || echo "Failed to get buildah info"
echo ""

# 5. Container Runtime Information
echo "=== CONTAINER RUNTIME ==="
which podman && podman version || echo "Podman not found"
which runc && runc --version || echo "runc not found"
which crun && crun --version || echo "crun not found"
echo ""

# 6. Namespace Capabilities
echo "=== NAMESPACE CAPABILITIES ==="
echo "Checking /proc/self/ns:"
ls -la /proc/self/ns/ 2>&1 || echo "Cannot list /proc/self/ns"
echo ""
echo "User namespace info:"
cat /proc/self/uid_map 2>&1 || echo "Cannot read uid_map"
cat /proc/self/gid_map 2>&1 || echo "Cannot read gid_map"
echo ""

# 7. Subuid/Subgid Mappings
echo "=== SUBUID/SUBGID MAPPINGS ==="
echo "Checking for user '$(whoami)' in subuid/subgid:"
grep "^$(whoami):" /etc/subuid 2>&1 || echo "No subuid entry for $(whoami)"
grep "^$(whoami):" /etc/subgid 2>&1 || echo "No subgid entry for $(whoami)"
echo ""
echo "Checking for 'build' user in subuid/subgid:"
grep "^build:" /etc/subuid 2>&1 || echo "No subuid entry for build"
grep "^build:" /etc/subgid 2>&1 || echo "No subgid entry for build"
echo ""

# 8. File System Permissions
echo "=== FILE SYSTEM PERMISSIONS ==="
echo "Home directory permissions:"
ls -la ~ | head -5
echo ""
echo "Container directories:"
ls -la ~/.local/share/containers 2>&1 || echo "~/.local/share/containers not found"
ls -la ~/.config/containers 2>&1 || echo "~/.config/containers not found"
echo ""
echo "Temp directories:"
ls -la /tmp | grep buildah 2>&1 || echo "No buildah directories in /tmp"
ls -la /var/tmp | grep buildah 2>&1 || echo "No buildah directories in /var/tmp"
echo ""

# 9. Storage Configuration
echo "=== STORAGE CONFIGURATION ==="
echo "Storage config locations:"
for conf in /etc/containers/storage.conf ~/.config/containers/storage.conf; do
    if [ -f "$conf" ]; then
        echo "Found: $conf"
        cat "$conf" | grep -E "(driver|runroot|graphroot)" | head -10
    else
        echo "Not found: $conf"
    fi
done
echo ""

# 10. Environment Variables
echo "=== ENVIRONMENT VARIABLES ==="
env | grep -E "(BUILDAH|CONTAINER|XDG_RUNTIME|TMPDIR|HOME|USER|PATH)" | sort
echo ""

# 11. SELinux/AppArmor Status
echo "=== SECURITY MODULES ==="
if command -v getenforce &> /dev/null; then
    echo "SELinux status: $(getenforce)"
    echo "SELinux context: $(id -Z 2>/dev/null || echo 'N/A')"
else
    echo "SELinux not found"
fi
echo ""
if [ -f /sys/kernel/security/apparmor/profiles ]; then
    echo "AppArmor loaded profiles: $(wc -l < /sys/kernel/security/apparmor/profiles)"
else
    echo "AppArmor not found"
fi
echo ""

# 12. Capabilities
echo "=== PROCESS CAPABILITIES ==="
if command -v capsh &> /dev/null; then
    capsh --print
else
    echo "capsh not found, trying getpcaps"
    getpcaps $$ 2>&1 || echo "Cannot determine capabilities"
fi
echo ""

# 13. Mount Information
echo "=== MOUNT INFORMATION ==="
echo "Checking for relevant mounts:"
mount | grep -E "(proc|sys|devpts|tmpfs|containers)" | head -20
echo ""
echo "Mount namespaces:"
ls -la /proc/self/ns/mnt 2>&1 || echo "Cannot check mount namespace"
echo ""

# 14. Test Buildah Unshare
echo "=== TESTING BUILDAH UNSHARE ==="
echo "Testing if we can use buildah unshare:"
buildah unshare cat /proc/self/uid_map 2>&1 || echo "buildah unshare failed"
echo ""

# 15. Test Basic Buildah Commands
echo "=== TESTING BASIC BUILDAH COMMANDS ==="
echo "Testing buildah from scratch:"
buildah --storage-driver=vfs from scratch 2>&1 || echo "Failed to create scratch container"
echo ""
echo "Listing containers:"
buildah --storage-driver=vfs containers 2>&1 || echo "Failed to list containers"
echo ""

# 16. Test Different Isolation Modes
echo "=== TESTING ISOLATION MODES ==="
for isolation in rootless chroot oci; do
    echo "Testing isolation=$isolation:"
    buildah --isolation=$isolation --storage-driver=vfs from scratch 2>&1 | head -5
    echo ""
done

# 17. Directory Creation Test
echo "=== TESTING DIRECTORY CREATION ==="
TEST_DIR="/tmp/buildah-test-$$"
echo "Creating test directory: $TEST_DIR"
mkdir -p "$TEST_DIR" 2>&1 && echo "Success" || echo "Failed"
ls -la "$TEST_DIR" 2>&1 || echo "Cannot list test directory"
rm -rf "$TEST_DIR" 2>&1
echo ""

# 18. Dockerfile Test
echo "=== TESTING SIMPLE DOCKERFILE BUILD ==="
cat > /tmp/Dockerfile.$$ << 'EOF'
FROM scratch
RUN echo "test"
EOF

echo "Testing build with debug logging:"
buildah --log-level=debug --storage-driver=vfs bud -f /tmp/Dockerfile.$$ 2>&1 | tail -50
rm -f /tmp/Dockerfile.$$
echo ""

# 19. Final System State
echo "=== FINAL CHECKS ==="
echo "Disk space:"
df -h / /tmp /var/tmp | grep -v "Filesystem"
echo ""
echo "Memory:"
free -h 2>/dev/null || echo "free command not available"
echo ""

echo "========================================"
echo "BUILDAH DEBUG PIPELINE - END"
echo "========================================"

# Cleanup any test containers
buildah --storage-driver=vfs rm -a 2>/dev/null || true
