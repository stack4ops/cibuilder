# Contributing to cibuilder

Thank you for your interest in contributing to cibuilder! This document provides guidelines for contributors.

## Code Quality Standards

### Shell Script Guidelines

1. **Use `set -eu`** to catch errors and undefined variables
2. **Quote variables** to prevent word splitting and globbing: `"$variable"`
3. **Use `printf`** instead of `echo` for portability and consistency
4. **Document functions** with inline comments explaining their purpose
5. **Keep line length** under 120 characters for readability
6. **Use meaningful variable names** that describe their purpose

### Example Shell Function

```sh
# Download and extract cibuild libraries with error checking
download_cibuild_libs() {
    url="${CIBUILDER_BIN_URL}/${CIBUILDER_BIN_REF}.tar.gz"
    echo "downloading cibuild libraries from ${url}..."

    if ! curl -fsSL "${url}" | tar xzf - --strip-components=1 "cibuild-${CIBUILDER_BIN_REF}/bin"; then
        echo >&2 "Error: failed to download cibuild libraries"
        return 1
    fi

    chmod -R 755 "bin"
    return 0
}
```

## Development Workflow

### Setting Up Development Environment

```bash
# Clone the repository
git clone https://github.com/stack4ops/cibuilder.git
cd cibuilder

# Install development tools
# Ubuntu/Debian
apt install shellcheck bats

# Or install Bats from source
git clone --depth 1 https://github.com/bats-core/bats-core.git /tmp/bats-build
cd /tmp/bats-build
./install.sh $HOME
rm -rf /tmp/bats-build

# Run tests
make test
```

### Pre-commit Hooks

Install the pre-commit hook to automatically check code quality:

```bash
cp .git/hooks/pre-commit.sample .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

### Making Changes

1. Create a feature branch:
   ```bash
   git checkout -b feature/my-feature
   ```

2. Make your changes following the code quality standards

3. Run tests:
   ```bash
   make test
   ```

4. Run shellcheck:
   ```bash
   shellcheck *.sh
   ```

5. Commit with meaningful messages:
   ```bash
   git commit -m "Add support for custom buildkitd flags"
   ```

6. Push and create a pull request

## Testing

### Running Tests

```bash
# Run all tests
make test

# Run with verbose output
make test-verbose

# Run specific test file
bats tests/buildctl-daemonless.bats
```

### Writing Tests

When adding new functionality, write corresponding tests:

```bats
@test "new function handles edge case correctly" {
    run new_function test_input
    [ "$status" -eq 0 ]
    [[ "$output" == *"expected"* ]]
}
```

## Dockerfile Best Practices

1. **Use multi-stage builds** to reduce final image size
2. **Combine RUN commands** with `&&` to minimize layers
3. **Use `--no-cache`** for apk installs
4. **Pin package versions** when possible
5. **Copy scripts** and set permissions in the same layer
6. **Use USER non-root** for security

### Example RUN Block

```dockerfile
RUN <<'EOF'
set -e
apk add --no-cache ca-certificates curl
curl -fsSL https://example.com/tool -o /usr/local/bin/tool
chmod +x /usr/local/bin/tool
EOF
```

## Documentation

### Updating Documentation

- Keep README.md up to date with new features
- Add environment variables to configuration documentation
- Update usage examples for new functionality
- Document breaking changes clearly

### Documentation Format

- Use clear section headings
- Provide usage examples
- Keep descriptions concise
- Link to related documentation

## Code Review Checklist

Before submitting a PR, ensure:

- [ ] All tests pass
- [ ] Shellcheck reports no errors
- [ ] Code follows style guidelines
- [ ] Documentation is updated
- [ ] No trailing whitespace
- [ ] Line lengths under 120 characters
- [ ] Security best practices followed
- [ ] Error handling is proper

## Reporting Issues

When reporting bugs:

1. Use the issue tracker
2. Provide clear description
3. Include steps to reproduce
4. Add relevant logs/error messages
5. Specify environment details

## Security Considerations

- Never commit secrets or credentials
- Use HTTPS for all downloads
- Validate external inputs
- Run as non-root user when possible
- Keep dependencies updated

## License

By contributing, you agree that your contributions will be licensed under the Apache-2.0 License.

## Questions?

- Open an issue for questions
- Join community discussions
- Check existing documentation

Thank you for contributing!