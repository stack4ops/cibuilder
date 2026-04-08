# Security Policy

## Supported Versions

| Version | Supported          |
|---------|-------------------|
| Latest  | :white_check_mark: |
| Older   | :x:                |

## Reporting a Vulnerability

If you discover a security vulnerability, please report it responsibly.

### How to Report

1. **Do NOT** create a public issue
2. Send a private vulnerability report using GitHub's private reporting feature
3. Include details about:
   - Affected versions
   - Steps to reproduce
   - Impact assessment

### Response Timeline

- **Initial response**: Within 48 hours
- **Investigation**: Within 7 days
- **Patch/fix**: As soon as possible, typically within 14 days
- **Public disclosure**: After fix is released

## Security Best Practices

### For Users

1. **Always use official images** from trusted registries
2. **Pin image versions** instead of using `latest`
3. **Scan images** for vulnerabilities before deployment
4. **Keep images updated** with security patches
5. **Run as non-root user** when possible
6. **Review Dockerfile** before building custom images

### Example: Pinning Image Version

```yaml
# Good
image: ghcr.io/stack4ops/cibuilder:v1.2.3

# Bad
image: ghcr.io/stack4ops/cibuilder:latest
```

### Scanning for Vulnerabilities

```bash
# Using Trivy
trivy image ghcr.io/stack4ops/cibuilder:v1.2.3

# Using Docker Scout
docker scout quickview ghcr.io/stack4ops/cibuilder:v1.2.3
```

## Security Features Built In

### User Security

- Runs as non-root user (`user`) by default
- Uses rootlessKit for additional isolation
- Configurable via `CIBUILDER_ROOTLESS_KIT` environment variable

### Network Security

- All downloads use HTTPS exclusively
- Validates TLS certificates
- No hardcoded credentials
- Environment-variable-based configuration

### Build Security

- Supports image signing with cosign
- Can verify image signatures during release
- SBOM generation for transparency
- Provenance attestation support

### Container Security

- Minimal attack surface (only required packages)
- Regular base image updates
- No unnecessary shell access
- Read-only filesystem where possible

## Handling Secrets

### Never Commit Secrets

Do NOT commit:
- API keys
- Passwords
- Tokens
- Certificates
- Private keys

### Using Secrets

Use CI/CD secret management:

```yaml
# GitLab CI example
variables:
  MY_REGISTRY_TOKEN: $MY_REGISTRY_TOKEN

deploy:
  variables:
    MY_REGISTRY_TOKEN: $MY_REGISTRY_TOKEN
```

## Dependency Management

### Regular Updates

- Base image (buildkit:rootless) updated weekly
- Kubernetes tools (kubectl) updated weekly
- Registry tools (regctl, cosign) updated weekly
- Embedded cibuild libs updated weekly

### Vulnerability Scanning

Automatic scanning in CI pipeline:
- Scan source code
- Scan Docker images
- Check dependencies

##Secure Configuration

### Production Mode

Lock embedded libraries to prevent external downloads:

```bash
docker run --rm \
  -e CIBUILD_RUN_CMD=build \
  -v /tmp/cibuilder.locked:/tmp/cibuilder.locked \
  ghcr.io/stack4ops/cibuilder:latest
```

### Disabling RootlessKit

If you need to debug and disable rootlessKit:

```bash
docker run --rm \
  -e CIBUILD_ROOTLESS_KIT=0 \
  -e CIBUILD_RUN_CMD=build \
  ghcr.io/stack4ops/cibuilder:latest
```

**Warning**: Only disable rootlessKit in trusted environments.

## Known Limitations

1. **Embedded Libraries**: Dynamic library loading may introduce supply chain risks
2. **Base Image**: Depends on upstream buildkit:rootless security
3. **Network**: Requires internet access for initial library downloads

## Security Updates

### Notification

Security updates will be announced via:
- GitHub security advisories
- Release notes
- Repository discussions

### Patching

When a security vulnerability is fixed:
1. New image version is released
2. Secret security advisory is published
3. Users are notified via GitHub
4. CVE is assigned if applicable

## Contact

For security questions not related to vulnerabilities:
- Open an issue with the `security` label
- Use the Discussions tab for general security questions

## Acknowledgments

We thank the community for:
- Responsible disclosure of vulnerabilities
- Security audits and reviews
- Contributing security improvements
- Reporting bugs and issues