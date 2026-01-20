#!/bin/bash

# Verification script to check if environment setup is complete

echo "========================================="
echo "Redis Enterprise Multicloud - Setup Check"
echo "========================================="
echo ""

ERRORS=0
WARNINGS=0
STEP=1

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ok() { echo -e "   ${GREEN}✓${NC} $1"; }
warn() { echo -e "   ${YELLOW}⚠${NC} $1"; WARNINGS=$((WARNINGS + 1)); }
fail() { echo -e "   ${RED}✗${NC} $1"; ERRORS=$((ERRORS + 1)); }
info() { echo -e "   ${BLUE}ℹ${NC} $1"; }

# ===========================================
# 1. Required CLI Tools
# ===========================================
echo "${STEP}. Checking required CLI tools..."
STEP=$((STEP + 1))

# OpenTofu/Terraform
if command -v tofu &> /dev/null; then
    ok "tofu installed: $(tofu version | head -1)"
elif command -v terraform &> /dev/null; then
    ok "terraform installed: $(terraform version | head -1)"
else
    fail "tofu or terraform not found"
    info "Install: https://opentofu.org/docs/intro/install/"
fi

# jq (required for version detection)
if command -v jq &> /dev/null; then
    ok "jq installed: $(jq --version)"
else
    fail "jq not found (required for Redis version detection)"
    info "Install: brew install jq (macOS) or apt install jq (Linux)"
fi

# curl
if command -v curl &> /dev/null; then
    ok "curl installed"
else
    fail "curl not found"
fi

# ===========================================
# 2. Cloud Provider CLIs
# ===========================================
echo ""
echo "${STEP}. Checking cloud provider CLIs..."
STEP=$((STEP + 1))

# AWS CLI
if command -v aws &> /dev/null; then
    ok "aws CLI installed: $(aws --version 2>&1 | cut -d' ' -f1)"
else
    warn "aws CLI not installed (required for AWS deployments)"
    info "Install: brew install awscli (macOS)"
fi

# Google Cloud SDK
if command -v gcloud &> /dev/null; then
    ok "gcloud CLI installed: $(gcloud version 2>/dev/null | head -1 | cut -d' ' -f4)"
else
    warn "gcloud CLI not installed (required for GCP deployments)"
    info "Install: brew install google-cloud-sdk (macOS)"
fi

# Azure CLI
if command -v az &> /dev/null; then
    ok "az CLI installed: $(az version 2>/dev/null | jq -r '.["azure-cli"]' 2>/dev/null || echo "unknown")"
else
    warn "az CLI not installed (required for Azure deployments)"
    info "Install: brew install azure-cli (macOS)"
fi

# ===========================================
# 3. Environment File
# ===========================================
echo ""
echo "${STEP}. Checking .env configuration..."
STEP=$((STEP + 1))

if [ ! -f ".env" ]; then
    fail ".env file not found"
    info "Create from template: cp .env.sample .env"
else
    ok ".env file exists"
    source .env

    # Required variables
    [ -n "$OWNER" ] && ok "OWNER is set: $OWNER" || fail "OWNER is not set"
    [ -n "$REDIS_LOGIN" ] && ok "REDIS_LOGIN is set" || fail "REDIS_LOGIN is not set"
    [ -n "$REDIS_PWD" ] && ok "REDIS_PWD is set" || fail "REDIS_PWD is not set"
    [ -n "$REDIS_DOWNLOAD_BASE_URL" ] && ok "REDIS_DOWNLOAD_BASE_URL is set" || fail "REDIS_DOWNLOAD_BASE_URL is not set"
    [ -n "$REDIS_OS" ] && ok "REDIS_OS is set: $REDIS_OS" || fail "REDIS_OS is not set"
    [ -n "$REDIS_ARCHITECTURE" ] && ok "REDIS_ARCHITECTURE is set: $REDIS_ARCHITECTURE" || fail "REDIS_ARCHITECTURE is not set"

    # Redis version (optional - auto-detected)
    if [ -n "$REDIS_VERSION" ] && [ -n "$REDIS_BUILD" ]; then
        ok "REDIS_VERSION is set: $REDIS_VERSION-$REDIS_BUILD"
    else
        info "Redis version will be auto-detected"
    fi
fi

# ===========================================
# 4. Credential Files
# ===========================================
echo ""
echo "${STEP}. Checking credential files..."
STEP=$((STEP + 1))

if [ -f ".env" ]; then
    source .env

    # AWS credentials
    if [ -n "$AWS_CREDENTIALS_FILE" ]; then
        eval AWS_CRED_PATH="$AWS_CREDENTIALS_FILE"
        if [ -f "$AWS_CRED_PATH" ]; then
            ok "AWS credentials file exists: $AWS_CREDENTIALS_FILE"
        else
            warn "AWS credentials file not found: $AWS_CREDENTIALS_FILE"
        fi
    else
        info "AWS_CREDENTIALS_FILE not configured"
    fi

    # GCP credentials
    if [ -n "$GCP_CREDENTIALS_FILE" ]; then
        eval GCP_CRED_PATH="$GCP_CREDENTIALS_FILE"
        if [ -f "$GCP_CRED_PATH" ]; then
            ok "GCP credentials file exists: $GCP_CREDENTIALS_FILE"
        else
            warn "GCP credentials file not found: $GCP_CREDENTIALS_FILE"
        fi
    else
        info "GCP_CREDENTIALS_FILE not configured"
    fi

    # Azure credentials
    if [ -n "$AZURE_CREDENTIALS_FILE" ]; then
        eval AZ_CRED_PATH="$AZURE_CREDENTIALS_FILE"
        if [ -f "$AZ_CRED_PATH" ]; then
            ok "Azure credentials file exists: $AZURE_CREDENTIALS_FILE"
        else
            warn "Azure credentials file not found: $AZURE_CREDENTIALS_FILE"
        fi
    else
        info "AZURE_CREDENTIALS_FILE not configured"
    fi
fi

# ===========================================
# 5. SSH Keys
# ===========================================
echo ""
echo "${STEP}. Checking SSH keys..."
STEP=$((STEP + 1))

if [ -f ".env" ]; then
    source .env

    # Main SSH key
    if [ -n "$SSH_PUBLIC_KEY" ]; then
        eval SSH_PUB_PATH="$SSH_PUBLIC_KEY"
        if [ -f "$SSH_PUB_PATH" ]; then
            ok "SSH public key exists: $SSH_PUBLIC_KEY"
        else
            fail "SSH public key not found: $SSH_PUBLIC_KEY"
        fi
    fi

    # Azure-specific RSA key
    if [ -n "$AZURE_SSH_PUBLIC_KEY" ]; then
        eval AZ_SSH_PATH="$AZURE_SSH_PUBLIC_KEY"
        if [ -f "$AZ_SSH_PATH" ]; then
            ok "Azure RSA key exists: $AZURE_SSH_PUBLIC_KEY"
        else
            warn "Azure RSA key not found: $AZURE_SSH_PUBLIC_KEY"
            info "Azure requires RSA keys. Generate: ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa"
        fi
    else
        info "AZURE_SSH_PUBLIC_KEY not configured (will use SSH_PUBLIC_KEY)"
    fi
fi

# ===========================================
# 6. .gitignore Check
# ===========================================
echo ""
echo "${STEP}. Checking security..."
STEP=$((STEP + 1))

if grep -q "^\.env$" .gitignore 2>/dev/null; then
    ok ".env is in .gitignore"
else
    fail ".env is NOT in .gitignore (security risk!)"
fi

# ===========================================
# Summary
# ===========================================
echo ""
echo "========================================="
echo "Summary"
echo "========================================="
echo -e "Errors:   ${RED}$ERRORS${NC}"
echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"
echo ""

if [ "$ERRORS" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed! Ready to deploy.${NC}"
    exit 0
elif [ "$ERRORS" -eq 0 ]; then
    echo -e "${YELLOW}⚠ Setup mostly complete. Review warnings above.${NC}"
    exit 0
else
    echo -e "${RED}✗ Setup incomplete. Fix the errors above.${NC}"
    exit 1
fi

