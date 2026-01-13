#!/bin/bash
# =============================================================================
# Toggle Sensitive Values in Terraform Files
# =============================================================================
# This script toggles between showing and hiding sensitive values in .tf files
# 
# Usage:
#   ./scripts/toggle_sensitive.sh show    # Comment out sensitive = true (show values)
#   ./scripts/toggle_sensitive.sh hide    # Uncomment sensitive = true (hide values)
#   ./scripts/toggle_sensitive.sh status  # Show current status
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

show_usage() {
    echo ""
    echo "Usage: $0 [show|hide|status]"
    echo ""
    echo "Commands:"
    echo "  show    - Comment out 'sensitive = true' to show values in logs (demo/POC mode)"
    echo "  hide    - Uncomment 'sensitive = true' to hide values in logs (production mode)"
    echo "  status  - Show current status of sensitive settings"
    echo ""
}

count_active() {
    grep -rE "^[^#]*sensitive\s*=\s*true" --include="*.tf" "$PROJECT_ROOT" 2>/dev/null | wc -l | tr -d ' '
}

count_commented() {
    grep -rE "^\s*#.*sensitive.*=.*true" --include="*.tf" "$PROJECT_ROOT" 2>/dev/null | wc -l | tr -d ' '
}

show_status() {
    local active=$(count_active)
    local commented=$(count_commented)
    
    echo ""
    echo -e "${BLUE}=== Sensitive Settings Status ===${NC}"
    echo ""
    echo -e "Active (hidden):     ${RED}${active}${NC} occurrences"
    echo -e "Commented (visible): ${GREEN}${commented}${NC} occurrences"
    echo ""
    
    if [ "$active" -gt 0 ]; then
        echo -e "${YELLOW}Current mode: PRODUCTION (sensitive values hidden)${NC}"
        echo ""
        echo "Active sensitive settings:"
        grep -rnE "^[^#]*sensitive\s*=\s*true" --include="*.tf" "$PROJECT_ROOT" 2>/dev/null | sed 's|'"$PROJECT_ROOT"'/||g' | while read line; do
            echo "  - $line"
        done
    else
        echo -e "${GREEN}Current mode: DEMO/POC (sensitive values visible)${NC}"
    fi
    echo ""
}

enable_show() {
    echo ""
    echo -e "${BLUE}=== Enabling DEMO/POC Mode (showing sensitive values) ===${NC}"
    echo ""
    
    local count=0
    
    # Find all .tf files and process them
    while IFS= read -r file; do
        if grep -q "sensitive\s*=\s*true" "$file" 2>/dev/null; then
            if ! grep -q "#.*sensitive.*=.*true" "$file" 2>/dev/null || grep -q "^\s*sensitive\s*=\s*true" "$file" 2>/dev/null; then
                # Comment out active sensitive = true lines
                sed -i.bak 's/^\([[:space:]]*\)sensitive[[:space:]]*=[[:space:]]*true/\1# sensitive = true  # Commented for demo\/POC transparency/g' "$file"
                rm -f "${file}.bak"
                count=$((count + 1))
                echo -e "  ${GREEN}✓${NC} Modified: ${file#$PROJECT_ROOT/}"
            fi
        fi
    done < <(find "$PROJECT_ROOT" -name "*.tf" -type f)
    
    echo ""
    if [ "$count" -gt 0 ]; then
        echo -e "${GREEN}Done! Modified $count file(s).${NC}"
        echo -e "${YELLOW}Note: Sensitive values will now appear in terraform output.${NC}"
    else
        echo -e "${YELLOW}No changes needed - already in DEMO/POC mode.${NC}"
    fi
    echo ""
}

enable_hide() {
    echo ""
    echo -e "${BLUE}=== Enabling PRODUCTION Mode (hiding sensitive values) ===${NC}"
    echo ""
    
    local count=0
    
    # Find all .tf files and process them
    while IFS= read -r file; do
        if grep -q "#.*sensitive.*=.*true" "$file" 2>/dev/null; then
            # Uncomment sensitive = true lines
            sed -i.bak 's/^[[:space:]]*#[[:space:]]*sensitive[[:space:]]*=[[:space:]]*true.*$/  sensitive = true/g' "$file"
            rm -f "${file}.bak"
            count=$((count + 1))
            echo -e "  ${GREEN}✓${NC} Modified: ${file#$PROJECT_ROOT/}"
        fi
    done < <(find "$PROJECT_ROOT" -name "*.tf" -type f)
    
    echo ""
    if [ "$count" -gt 0 ]; then
        echo -e "${GREEN}Done! Modified $count file(s).${NC}"
        echo -e "${YELLOW}Note: Sensitive values will now be hidden in terraform output.${NC}"
    else
        echo -e "${YELLOW}No changes needed - already in PRODUCTION mode.${NC}"
    fi
    echo ""
}

# Main
case "${1:-}" in
    show)
        enable_show
        ;;
    hide)
        enable_hide
        ;;
    status)
        show_status
        ;;
    *)
        show_usage
        exit 1
        ;;
esac

