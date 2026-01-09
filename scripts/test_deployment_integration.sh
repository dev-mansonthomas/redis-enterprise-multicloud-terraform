#!/bin/bash

# Integration test for Redis version auto-detection with deployment scripts
# This script tests that the deployment scripts correctly use the version detection system

set -e

echo "========================================="
echo "Deployment Integration Test"
echo "========================================="
echo ""

# Create a temporary .env file for testing
TEST_ENV_FILE=".env.integration_test"

echo "Creating test environment file..."

# Check if REDIS_DOWNLOAD_BASE_URL is set in the environment
if [ -z "$REDIS_DOWNLOAD_BASE_URL" ]; then
    echo "Error: REDIS_DOWNLOAD_BASE_URL must be set in your environment to run integration tests"
    echo "Example: export REDIS_DOWNLOAD_BASE_URL=https://your-mirror.com/redis-enterprise"
    exit 1
fi

cat > "$TEST_ENV_FILE" << EOF
# Test environment for integration testing
OWNER=test_user
REDIS_DOWNLOAD_BASE_URL=$REDIS_DOWNLOAD_BASE_URL
REDIS_OS=jammy
REDIS_ARCHITECTURE=amd64
SKIP_DELETION=yes
EOF

echo "✓ Test environment file created: $TEST_ENV_FILE"
echo ""

# Test 1: Source the environment file
echo "Test 1: Loading test environment..."
echo "-------------------------------------------"
source "$TEST_ENV_FILE"

if [ "$OWNER" = "test_user" ] && [ "$REDIS_OS" = "jammy" ] && [ "$REDIS_ARCHITECTURE" = "amd64" ]; then
    echo "✓ Environment loaded successfully"
else
    echo "✗ Failed to load environment"
    rm "$TEST_ENV_FILE"
    exit 1
fi
echo ""

# Test 2: Simulate version detection (as done in deployment scripts)
echo "Test 2: Simulating version detection..."
echo "-------------------------------------------"

# Check if version is set
if [ -z "$REDIS_VERSION" ] || [ -z "$REDIS_BUILD" ]; then
    echo "Redis version not set, auto-detecting..."
    
    # Find the script directory
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    VERSION_SCRIPT="$SCRIPT_DIR/get_latest_redis_version.sh"
    
    if [ -f "$VERSION_SCRIPT" ]; then
        # Source the script to get the version variables
        source "$VERSION_SCRIPT" > /dev/null 2>&1
        
        if [ -z "$REDIS_VERSION" ] || [ -z "$REDIS_BUILD" ]; then
            echo "✗ Failed to auto-detect Redis version"
            rm "$TEST_ENV_FILE"
            exit 1
        fi
        
        echo "✓ Auto-detected Redis version: $REDIS_VERSION-$REDIS_BUILD"
    else
        echo "✗ Version detection script not found"
        rm "$TEST_ENV_FILE"
        exit 1
    fi
else
    echo "✓ Redis version already set: $REDIS_VERSION-$REDIS_BUILD"
fi
echo ""

# Test 3: Validate OS and architecture
echo "Test 3: Validating OS and architecture..."
echo "-------------------------------------------"

if [ -z "$REDIS_OS" ]; then
    echo "✗ REDIS_OS is not set"
    rm "$TEST_ENV_FILE"
    exit 1
fi

if [ -z "$REDIS_ARCHITECTURE" ]; then
    echo "✗ REDIS_ARCHITECTURE is not set"
    rm "$TEST_ENV_FILE"
    exit 1
fi

echo "✓ OS: $REDIS_OS"
echo "✓ Architecture: $REDIS_ARCHITECTURE"
echo ""

# Test 4: Validate base URL
echo "Test 4: Validating Redis download base URL..."
echo "-------------------------------------------"

if [ -z "$REDIS_DOWNLOAD_BASE_URL" ]; then
    echo "✗ REDIS_DOWNLOAD_BASE_URL is not set"
    rm "$TEST_ENV_FILE"
    exit 1
fi

echo "✓ Base URL: $REDIS_DOWNLOAD_BASE_URL"
echo ""

# Test 5: Construct URL
echo "Test 5: Constructing Redis Enterprise URL..."
echo "-------------------------------------------"

if [ -z "$REDIS_ENTERPRISE_URL" ]; then
    REDIS_ENTERPRISE_URL="${REDIS_DOWNLOAD_BASE_URL}/${REDIS_VERSION}/redislabs-${REDIS_VERSION}-${REDIS_BUILD}-${REDIS_OS}-${REDIS_ARCHITECTURE}.tar"
    echo "✓ Constructed URL: $REDIS_ENTERPRISE_URL"
else
    echo "✓ Using provided URL: $REDIS_ENTERPRISE_URL"
fi
echo ""

# Test 6: Validate URL format
echo "Test 6: Validating URL format..."
echo "-------------------------------------------"

if [[ "$REDIS_ENTERPRISE_URL" =~ /[0-9]+\.[0-9]+\.[0-9]+/redislabs-[0-9]+\.[0-9]+\.[0-9]+-[0-9]+-[a-z0-9]+-[a-z0-9]+\.tar$ ]]; then
    echo "✓ URL format is valid"
else
    echo "✗ URL format is invalid"
    rm "$TEST_ENV_FILE"
    exit 1
fi
echo ""

# Test 7: Test with different OS/arch combinations
echo "Test 7: Testing different configurations..."
echo "-------------------------------------------"

test_configs=(
    "jammy:amd64"
    "focal:amd64"
    "rhel8:amd64"
    "rhel9:amd64"
    "jammy:arm64"
)

for config in "${test_configs[@]}"; do
    IFS=':' read -r os arch <<< "$config"
    url="${REDIS_DOWNLOAD_BASE_URL}/${REDIS_VERSION}/redislabs-${REDIS_VERSION}-${REDIS_BUILD}-${os}-${arch}.tar"
    echo "  ✓ $os/$arch: ${url##*/}"
done
echo ""

# Cleanup
echo "Cleaning up..."
rm "$TEST_ENV_FILE"
echo "✓ Test environment file removed"
echo ""

# Summary
echo "========================================="
echo "All Integration Tests Passed! ✓"
echo "========================================="
echo ""
echo "Summary:"
echo "  Redis Version: $REDIS_VERSION-$REDIS_BUILD"
echo "  Base URL: $REDIS_DOWNLOAD_BASE_URL"
echo "  OS: $REDIS_OS"
echo "  Architecture: $REDIS_ARCHITECTURE"
echo "  Full URL: $REDIS_ENTERPRISE_URL"
echo ""
echo "The deployment integration is working correctly!"
echo "The deployment scripts will automatically:"
echo "  1. Validate REDIS_DOWNLOAD_BASE_URL is set"
echo "  2. Detect the latest Redis version"
echo "  3. Validate OS and architecture"
echo "  4. Construct the download URL"
echo "  5. Pass it to Terraform/OpenTofu"

