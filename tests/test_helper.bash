#!/usr/bin/env bats

# Ensure we're running from the correct directory
setup() {
    cd "$BATS_TEST_DIRNAME/.."
}

# Helper function to check if a required tool is available
check_tool() {
    command -v "$1" &>/dev/null
}

# Helper function to check file permissions
file_perms() {
    ls -ld "$1" | awk '{print $1}'
}

# Helper function to get file owner
file_owner() {
    ls -ld "$1" | awk '{print $3 ":" $4}'
}