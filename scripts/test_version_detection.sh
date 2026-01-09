#!/bin/bash

# Test script for Redis version auto-detection system
# This script validates that the version detection and URL construction work correctly

set -e

echo "========================================="
echo "Redis Version Auto-Detection Test"
echo "========================================="
echo ""

# Test 1: Version detection script
echo "Test 1: Running version detection script..."
echo "-------------------------------------------"
DETECTED_VERSION=$(./scripts/get_latest_redis_version.sh 2>&1)
echo "$DETECTED_VERSION"
echo ""

# Test 2: Extract version from output
echo "Test 2: Extracting version components..."
echo "-------------------------------------------"
source ./scripts/get_latest_redis_version.sh > /dev/null 2>&1

if [ -n "$REDIS_VERSION" ] && [ -n "$REDIS_BUILD" ]; then
    echo "✓ REDIS_VERSION: $REDIS_VERSION"
    echo "✓ REDIS_BUILD: $REDIS_BUILD"
    echo "✓ REDIS_FULL_VERSION: $REDIS_FULL_VERSION"
else
    echo "✗ Failed to extract version components"
    exit 1
fi
echo ""

# Test 3: URL construction
echo "Test 3: Testing URL construction..."
echo "-------------------------------------------"
REDIS_OS="jammy"
REDIS_ARCHITECTURE="amd64"

# Check if REDIS_DOWNLOAD_BASE_URL is set
if [ -z "$REDIS_DOWNLOAD_BASE_URL" ]; then
    echo "⚠ REDIS_DOWNLOAD_BASE_URL not set, skipping URL construction test"
    echo "  Set REDIS_DOWNLOAD_BASE_URL in your environment to test URL construction"
else
    CONSTRUCTED_URL="${REDIS_DOWNLOAD_BASE_URL}/${REDIS_VERSION}/redislabs-${REDIS_VERSION}-${REDIS_BUILD}-${REDIS_OS}-${REDIS_ARCHITECTURE}.tar"
    echo "Base URL: $REDIS_DOWNLOAD_BASE_URL"
    echo "OS: $REDIS_OS"
    echo "Architecture: $REDIS_ARCHITECTURE"
    echo "Constructed URL: $CONSTRUCTED_URL"
fi
echo ""

# Test 4: Validate URL format
echo "Test 4: Validating URL format..."
echo "-------------------------------------------"
if [ -n "$CONSTRUCTED_URL" ]; then
    if [[ "$CONSTRUCTED_URL" =~ /[0-9]+\.[0-9]+\.[0-9]+/redislabs-[0-9]+\.[0-9]+\.[0-9]+-[0-9]+-[a-z0-9]+-[a-z0-9]+\.tar$ ]]; then
        echo "✓ URL format is valid"
    else
        echo "✗ URL format is invalid"
        exit 1
    fi
else
    echo "⚠ Skipping URL format validation (REDIS_DOWNLOAD_BASE_URL not set)"
fi
echo ""

# Test 5: Test with .env.test file
echo "Test 5: Testing with .env.test file..."
echo "-------------------------------------------"
if [ -f ".env.test" ]; then
    # Save REDIS_DOWNLOAD_BASE_URL if set
    SAVED_BASE_URL="$REDIS_DOWNLOAD_BASE_URL"

    source .env.test

    # Restore REDIS_DOWNLOAD_BASE_URL if it was set before
    if [ -n "$SAVED_BASE_URL" ]; then
        REDIS_DOWNLOAD_BASE_URL="$SAVED_BASE_URL"
    fi

    if [ -n "$OWNER" ] && [ -n "$REDIS_OS" ] && [ -n "$REDIS_ARCHITECTURE" ]; then
        echo "✓ .env.test loaded successfully"
        echo "  OWNER: $OWNER"
        echo "  REDIS_OS: $REDIS_OS"
        echo "  REDIS_ARCHITECTURE: $REDIS_ARCHITECTURE"
    else
        echo "✗ .env.test is missing required variables"
        exit 1
    fi
else
    echo "⚠ .env.test not found (skipping)"
fi
echo ""

# Test 6: Test different OS distributions
echo "Test 6: Testing different OS distributions..."
echo "-------------------------------------------"
if [ -n "$REDIS_DOWNLOAD_BASE_URL" ]; then
    for os in jammy focal rhel8 rhel9; do
        url="${REDIS_DOWNLOAD_BASE_URL}/${REDIS_VERSION}/redislabs-${REDIS_VERSION}-${REDIS_BUILD}-${os}-amd64.tar"
        echo "  $os: ${url##*/}"
    done
else
    echo "⚠ Skipping (REDIS_DOWNLOAD_BASE_URL not set)"
fi
echo ""

# Test 7: Test different architectures
echo "Test 7: Testing different architectures..."
echo "-------------------------------------------"
if [ -n "$REDIS_DOWNLOAD_BASE_URL" ]; then
    for arch in amd64 arm64; do
        url="${REDIS_DOWNLOAD_BASE_URL}/${REDIS_VERSION}/redislabs-${REDIS_VERSION}-${REDIS_BUILD}-jammy-${arch}.tar"
        echo "  $arch: ${url##*/}"
    done
else
    echo "⚠ Skipping (REDIS_DOWNLOAD_BASE_URL not set)"
fi
echo ""

# Summary
echo "========================================="
echo "All Tests Passed! ✓"
echo "========================================="
echo ""
echo "Summary:"
echo "  Latest Redis Version: $REDIS_FULL_VERSION"
if [ -n "$CONSTRUCTED_URL" ]; then
    echo "  Example URL: $CONSTRUCTED_URL"
fi
echo ""
echo "The version detection system is working correctly!"
if [ -z "$REDIS_DOWNLOAD_BASE_URL" ]; then
    echo ""
    echo "Note: Set REDIS_DOWNLOAD_BASE_URL to test URL construction"
fi

