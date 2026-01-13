#!/bin/bash
#
# Migration script to update all tf.json files and variables.tf
# to use the new unified Redis Enterprise installation scripts
#
# This script adds:
# - ssh_private_key to modules/*/re module calls
# - flash_enabled to modules/*/re module calls
# - Corresponding variables to variables.tf files
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=== Migration to Unified Redis Enterprise Scripts ==="
echo "Project root: $PROJECT_ROOT"

# Function to add variables to variables.tf if they don't exist
add_variables_to_tf() {
    local file="$1"
    local ssh_key_default="$2"
    
    if ! grep -q "ssh_private_key" "$file"; then
        echo "  Adding ssh_private_key to $file"
        # Find the line after ssh_public_key and add ssh_private_key
        sed -i.bak '/^variable "ssh_public_key"/,/^}$/ {
            /^}$/a\
\
variable "ssh_private_key" {\
  description = "Path to SSH private key for provisioners"\
  default     = "'"$ssh_key_default"'"\
}
        }' "$file"
    fi
    
    if ! grep -q "flash_enabled" "$file"; then
        echo "  Adding flash_enabled to $file"
        # Add flash_enabled after ssh_user block
        sed -i.bak '/^variable "ssh_user"/,/^}$/ {
            /^}$/a\
\
variable "flash_enabled" {\
  description = "Enable Redis on Flash"\
  type        = bool\
  default     = false\
}
        }' "$file"
    fi
    
    # Clean up backup files
    rm -f "${file}.bak"
}

# Function to update tf.json file - add ssh_private_key and flash_enabled to RE modules only
update_tf_json() {
    local file="$1"
    
    echo "  Processing $file"
    
    # Use Python for reliable JSON manipulation
    python3 << EOF
import json
import sys

with open('$file', 'r') as f:
    data = json.load(f)

modified = False

if 'module' in data:
    for module_name, module_config in data['module'].items():
        source = module_config.get('source', '')
        # Only modify RE modules (aws/re, gcp/re, azure/re)
        if '/re' in source and any(x in source for x in ['aws/re', 'gcp/re', 'azure/re']):
            # Add ssh_private_key if not present (after ssh_public_key)
            if 'ssh_public_key' in module_config and 'ssh_private_key' not in module_config:
                module_config['ssh_private_key'] = '\${var.ssh_private_key}'
                modified = True
            
            # Add flash_enabled if not present (after private_conf)
            if 'private_conf' in module_config and 'flash_enabled' not in module_config:
                module_config['flash_enabled'] = '\${var.flash_enabled}'
                modified = True

if modified:
    with open('$file', 'w') as f:
        json.dump(data, f, indent=4)
    print(f"    Modified: $file")
else:
    print(f"    No changes needed: $file")
EOF
}

echo ""
echo "=== Updating AWS configurations ==="
for config_dir in "$PROJECT_ROOT"/main/AWS/*/; do
    for subdir in "$config_dir"*/; do
        if [ -f "$subdir/variables.tf" ]; then
            echo "Processing: $subdir"
            
            # Detect SSH key format from existing variable
            if grep -q "id_ed25519" "$subdir/variables.tf"; then
                ssh_default="~/.ssh/id_ed25519"
            else
                ssh_default="~/.ssh/id_rsa"
            fi
            
            add_variables_to_tf "$subdir/variables.tf" "$ssh_default"
            
            # Update all tf.json files in this directory
            for tf_json in "$subdir"*.tf.json; do
                [ -f "$tf_json" ] && update_tf_json "$tf_json"
            done
        fi
    done
done

echo ""
echo "=== Updating GCP configurations ==="
for config_dir in "$PROJECT_ROOT"/main/GCP/*/; do
    for subdir in "$config_dir"*/; do
        if [ -f "$subdir/variables.tf" ]; then
            echo "Processing: $subdir"
            ssh_default="~/.ssh/id_rsa"
            add_variables_to_tf "$subdir/variables.tf" "$ssh_default"
            
            for tf_json in "$subdir"*.tf.json; do
                [ -f "$tf_json" ] && update_tf_json "$tf_json"
            done
        fi
    done
done

echo ""
echo "=== Updating Azure configurations ==="
for config_dir in "$PROJECT_ROOT"/main/Azure/*/; do
    for subdir in "$config_dir"*/; do
        if [ -f "$subdir/variables.tf" ]; then
            echo "Processing: $subdir"
            ssh_default="~/.ssh/id_rsa"
            add_variables_to_tf "$subdir/variables.tf" "$ssh_default"
            
            for tf_json in "$subdir"*.tf.json; do
                [ -f "$tf_json" ] && update_tf_json "$tf_json"
            done
        fi
    done
done

echo ""
echo "=== Migration Complete ==="
echo "Please review the changes and run 'terraform validate' on each configuration."

