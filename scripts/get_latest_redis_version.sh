#!/bin/bash

# Script to detect the latest Redis Enterprise Software version
# This script scrapes the Redis release notes pages to find the latest version

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# URLs
RELEASE_NOTES_URL="https://redis.io/docs/latest/operate/rs/release-notes/"

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1" >&2
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Function to extract the latest major version from the main release notes page
get_latest_major_version() {
    print_info "Fetching latest major version from Redis release notes..."

    # Fetch the page and extract the first version link (e.g., "8.0.x releases")
    local html=$(curl -s "$RELEASE_NOTES_URL")

    # Extract the first major version (e.g., "8.0")
    # Looking for pattern like "8.0.x releases" in the HTML
    local major_version=$(echo "$html" | grep -o '[0-9]\+\.[0-9]\+\.x releases' | head -1 | sed 's/\.x releases//')

    if [ -z "$major_version" ]; then
        print_error "Could not extract major version from release notes"
        return 1
    fi

    print_info "Latest major version: $major_version"
    echo "$major_version"
}

# Function to extract the latest full version from the major version page
get_latest_full_version() {
    local major_version=$1

    # Convert 8.0 to 8-0 for URL
    local url_version=$(echo "$major_version" | tr '.' '-')
    local version_url="${RELEASE_NOTES_URL}rs-${url_version}-releases/"

    print_info "Fetching latest full version from $version_url..."

    # Fetch the page
    local html=$(curl -s "$version_url")

    # Extract the first full version (e.g., "8.0.6-54")
    # Looking for pattern like "8.0.6-54 (December 2025)" in the HTML
    local full_version=$(echo "$html" | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+-[0-9]\+ (' | head -1 | sed 's/ ($//')

    if [ -z "$full_version" ]; then
        print_error "Could not extract full version from $version_url"
        return 1
    fi

    print_info "Latest full version: $full_version"
    echo "$full_version"
}

# Function to extract version components
extract_version_components() {
    local full_version=$1
    
    # Extract major.minor.patch (e.g., "8.0.6" from "8.0.6-54")
    local version_number=$(echo "$full_version" | cut -d'-' -f1)
    
    # Extract build number (e.g., "54" from "8.0.6-54")
    local build_number=$(echo "$full_version" | cut -d'-' -f2)
    
    echo "$version_number" "$build_number"
}

# Main function
main() {
    print_info "Starting Redis Enterprise version detection..."

    # Get latest major version
    local major_version=$(get_latest_major_version)
    if [ $? -ne 0 ] || [ -z "$major_version" ]; then
        print_error "Failed to get major version"
        exit 1
    fi

    # Get latest full version
    local full_version=$(get_latest_full_version "$major_version")
    if [ $? -ne 0 ] || [ -z "$full_version" ]; then
        print_error "Failed to get full version"
        exit 1
    fi

    # Extract components
    read version_number build_number <<< $(extract_version_components "$full_version")

    # Display results
    echo "" >&2
    echo "=========================================" >&2
    echo "Redis Enterprise Latest Version" >&2
    echo "=========================================" >&2
    echo "Full version:    $full_version" >&2
    echo "Version number:  $version_number" >&2
    echo "Build number:    $build_number" >&2
    echo "=========================================" >&2
    echo "" >&2

    # Export as environment variables (for sourcing)
    export REDIS_VERSION="$version_number"
    export REDIS_BUILD="$build_number"
    export REDIS_FULL_VERSION="$full_version"

    # Output to stdout for easy capture
    echo "$full_version"

    # If script is sourced, variables will be available
    # If script is executed, print export commands
    if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
        echo "" >&2
        echo "To use these values, run:" >&2
        echo "  export REDIS_VERSION=\"$version_number\"" >&2
        echo "  export REDIS_BUILD=\"$build_number\"" >&2
        echo "  export REDIS_FULL_VERSION=\"$full_version\"" >&2
        echo "" >&2
        echo "Or source this script:" >&2
        echo "  source $0" >&2
    fi
}

# Run main function
main

