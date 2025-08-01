#!/bin/bash

# Test runner for infrastructure tests
# Requires BATS to be installed

set -e

echo "Running infrastructure tests..."

# Check if bats is available
if ! command -v bats &> /dev/null; then
    echo "BATS is required but not installed. Installing BATS..."
    
    # Try to install bats via package manager
    if command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y bats
    elif command -v yum &> /dev/null; then
        sudo yum install -y bats
    elif command -v brew &> /dev/null; then
        brew install bats-core
    else
        echo "Please install BATS manually: https://github.com/bats-core/bats-core"
        exit 1
    fi
fi

# Run the tests
bats test/unit/test_infrastructure.bats

echo "All infrastructure tests completed!"