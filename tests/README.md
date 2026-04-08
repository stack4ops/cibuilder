# Bats Tests for cibuilder

This directory contains Bats (Bash Automated Testing System) tests for the cibuilder project.

## Prerequisites

Bats must be installed. Install it using:

```bash
git clone --depth 1 https://github.com/bats-core/bats-core.git /tmp/bats-build
cd /tmp/bats-build
./install.sh $HOME
rm -rf /tmp/bats-build
```

## Running Tests

Run all tests:

```bash
bats tests/*.bats
```

Run a specific test file:

```bash
bats tests/buildctl-daemonless.bats
```

Run with verbose output:

```bash
bats -t tests/*.bats
```

Run and count the number of failed tests:

```bash
bats tests/*.bats; echo "Exit code: $?"
```

## Test Files

- **buildctl-daemonless.bats** - Tests for the buildctl-daemonless.sh script
- **cibuild_entrypoint.bats** - Tests for the cibuild_entrypoint.sh script
- **dockerfile.bats** - Tests for the Dockerfile
- **readme.bats** - Tests for the README.md documentation

## Test Coverage

The tests verify:
- File existence and executability
- Correct shebang lines (`#!/bin/sh`)
- Error handling (set -eu)
- Environment variable handling
- Script functionality and architecture
- Dockerfile configuration
- Documentation completeness