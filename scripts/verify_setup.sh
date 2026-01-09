#!/bin/bash

# Verification script to check if tagging and credentials setup is complete

echo "========================================="
echo "Verifying Tagging and Credentials Setup"
echo "========================================="
echo ""

ERRORS=0
WARNINGS=0

# Check if .env.sample exists
echo "1. Checking .env.sample..."
if [ -f ".env.sample" ]; then
    echo "   ✓ .env.sample exists"
else
    echo "   ✗ .env.sample not found"
    ERRORS=$((ERRORS + 1))
fi

# Check if .env exists
echo "2. Checking .env..."
if [ -f ".env" ]; then
    echo "   ✓ .env exists"

    # Check if OWNER is set
    source .env
    if [ -n "$OWNER" ]; then
        echo "   ✓ OWNER is set: $OWNER"
    else
        echo "   ✗ OWNER is not set in .env"
        ERRORS=$((ERRORS + 1))
    fi

    # Check Redis download base URL
    if [ -n "$REDIS_DOWNLOAD_BASE_URL" ]; then
        echo "   ✓ REDIS_DOWNLOAD_BASE_URL is set"
    else
        echo "   ✗ REDIS_DOWNLOAD_BASE_URL is not set in .env"
        ERRORS=$((ERRORS + 1))
    fi

    # Check Redis configuration
    if [ -n "$REDIS_OS" ]; then
        echo "   ✓ REDIS_OS is set: $REDIS_OS"
    else
        echo "   ✗ REDIS_OS is not set in .env"
        ERRORS=$((ERRORS + 1))
    fi

    if [ -n "$REDIS_ARCHITECTURE" ]; then
        echo "   ✓ REDIS_ARCHITECTURE is set: $REDIS_ARCHITECTURE"
    else
        echo "   ✗ REDIS_ARCHITECTURE is not set in .env"
        ERRORS=$((ERRORS + 1))
    fi

    # Check if Redis version is set or can be auto-detected
    if [ -n "$REDIS_VERSION" ] && [ -n "$REDIS_BUILD" ]; then
        echo "   ✓ REDIS_VERSION is set: $REDIS_VERSION-$REDIS_BUILD"
    elif [ -n "$REDIS_ENTERPRISE_URL" ]; then
        echo "   ✓ REDIS_ENTERPRISE_URL is set (version will be auto-detected)"
    else
        echo "   ⚠ Redis version not set (will be auto-detected from redis.io)"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo "   ⚠ .env not found (you need to create it from .env.sample)"
    WARNINGS=$((WARNINGS + 1))
fi

# Check if .env is in .gitignore
echo "3. Checking .gitignore..."
if grep -q "^\.env$" .gitignore 2>/dev/null; then
    echo "   ✓ .env is in .gitignore"
else
    echo "   ✗ .env is not in .gitignore"
    ERRORS=$((ERRORS + 1))
fi

# Check if variables.tf files have owner and skip_deletion variables
echo "4. Checking variables.tf files..."
VARIABLES_FILES=$(find main -name "variables.tf" -type f | wc -l)
VARIABLES_WITH_OWNER=$(find main -name "variables.tf" -type f -exec grep -l "variable \"owner\"" {} \; | wc -l)
VARIABLES_WITH_SKIP=$(find main -name "variables.tf" -type f -exec grep -l "variable \"skip_deletion\"" {} \; | wc -l)

echo "   Found $VARIABLES_FILES variables.tf files"
echo "   $VARIABLES_WITH_OWNER have 'owner' variable"
echo "   $VARIABLES_WITH_SKIP have 'skip_deletion' variable"

if [ "$VARIABLES_FILES" -eq "$VARIABLES_WITH_OWNER" ] && [ "$VARIABLES_FILES" -eq "$VARIABLES_WITH_SKIP" ]; then
    echo "   ✓ All variables.tf files have required variables"
else
    echo "   ✗ Some variables.tf files are missing required variables"
    ERRORS=$((ERRORS + 1))
fi

# Check if .tf.json files have locals block
echo "5. Checking .tf.json configuration files..."
TF_JSON_FILES=$(find main -name "*.tf.json" -type f | wc -l)
TF_JSON_WITH_LOCALS=$(find main -name "*.tf.json" -type f -exec grep -l "\"locals\"" {} \; | wc -l)

echo "   Found $TF_JSON_FILES .tf.json files"
echo "   $TF_JSON_WITH_LOCALS have 'locals' block"

if [ "$TF_JSON_FILES" -eq "$TF_JSON_WITH_LOCALS" ]; then
    echo "   ✓ All .tf.json files have locals block"
else
    echo "   ⚠ Some .tf.json files might be missing locals block"
    WARNINGS=$((WARNINGS + 1))
fi

# Check if deployment scripts exist
echo "6. Checking deployment scripts..."
DIRS_WITH_VARIABLES=$(find main -name "variables.tf" -type f -exec dirname {} \;)
MISSING_SCRIPTS=0

for dir in $DIRS_WITH_VARIABLES; do
    if [ ! -f "$dir/tofu_apply.sh" ] || [ ! -f "$dir/tofu_destroy.sh" ]; then
        echo "   ✗ Missing scripts in: $dir"
        MISSING_SCRIPTS=$((MISSING_SCRIPTS + 1))
    fi
done

if [ "$MISSING_SCRIPTS" -eq 0 ]; then
    echo "   ✓ All configuration directories have deployment scripts"
else
    echo "   ✗ $MISSING_SCRIPTS directories are missing deployment scripts"
    ERRORS=$((ERRORS + 1))
fi

# Check if template scripts exist
echo "7. Checking template scripts..."
if [ -f "scripts/tofu_apply_template.sh" ] && [ -f "scripts/tofu_destroy_template.sh" ]; then
    echo "   ✓ Template scripts exist"
else
    echo "   ✗ Template scripts not found in scripts/ directory"
    ERRORS=$((ERRORS + 1))
fi

# Check if documentation exists
echo "8. Checking documentation..."
if [ -f "TAGGING_AND_CREDENTIALS.md" ]; then
    echo "   ✓ TAGGING_AND_CREDENTIALS.md exists"
else
    echo "   ✗ TAGGING_AND_CREDENTIALS.md not found"
    ERRORS=$((ERRORS + 1))
fi

# Summary
echo ""
echo "========================================="
echo "Verification Summary"
echo "========================================="
echo "Errors: $ERRORS"
echo "Warnings: $WARNINGS"
echo ""

if [ "$ERRORS" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
    echo "✓ All checks passed! Setup is complete."
    exit 0
elif [ "$ERRORS" -eq 0 ]; then
    echo "⚠ Setup is mostly complete, but there are some warnings."
    exit 0
else
    echo "✗ Setup is incomplete. Please fix the errors above."
    exit 1
fi

