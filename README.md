# cibuilder

Multi-stage CI build environment based on `buildkit:rootless` with embedded `cibuild` libraries from https://github.com/stack4ops/cibuild.

## Features

### Customizations of buildkit:rootless

**Check Tools:**
- `regctl` - Container registry operations
- `jq` - JSON processor

**Build Tools:**
- `buildctl` - Direct BuildKit communication over mTLS
- `docker-cli` - Docker command-line interface
- `buildx` - BuildKit CLI for Docker

**Test Tools:**
- `kubectl` - Kubernetes management
- `docker-cli` - Container testing in DInD environments

**Release Tools:**
- `regctl` - Multi-arch image index creation
- `cosign` - Container image signing

### Embedded cibuild Libraries

Uses the latest `cibuild` libraries for standardized CI/CD operations.

### Enhanced Entrypoint

Custom `cibuild_entrypoint.sh` with the following improvements:

1. **Command Execution Based on Environment:**
   ```bash
   cibuild -r main|check|build|test|release
   ```
   Controlled by `CIBUILD_RUN_CMD` environment variable.

2. **Dynamic cibuild Library Loading:**
   - Override embedded libraries via environment variables:
     - `CIBUILDER_BIN_URL` - Custom download URL
     - `CIBUILDER_BIN_REF` - Custom version/branch/tag
   - Useful for development and debugging
   - Can be disabled in production by mounting `/tmp/cibuilder.locked` as an empty volume

3. **Generic BUILDKITD_FLAGS:**
   - Default: `-oci-worker-no-process-sandbox`
   - Works in most environments
   - Overridable via `BUILDKITD_FLAGS` environment variable

4. **Rootlesskit Mode:**
   - Controlled by `CIBUILDER_ROOTLESS_KIT` (default: 1)
   - Enable or disable based on specific requirements

### Local Registry Support

Includes CA certificates for trusting a local development registry.

## Architecture Support

Multi-architecture support:
- `amd64`
- `arm64`

## Usage

### Basic Usage

```bash
# Pull the image
docker pull ghcr.io/stack4ops/cibuilder:latest

# Run check command
docker run --rm \
  -e CIBUILD_RUN_CMD=check \
  ghcr.io/stack4ops/cibuilder:latest

# Run build command
docker run --rm \
  -e CIBUILD_RUN_CMD=build \
  ghcr.io/stack4ops/cibuilder:latest
```

### Custom cibuild Library Version

```bash
# Use a specific branch/tag
docker run --rm \
  -e CIBUILD_RUN_CMD=build \
  -e CIBUILDER_BIN_URL=https://github.com/stack4ops/cibuild/archive/refs/heads \
  -e CIBUILDER_BIN_REF=feature-branch \
  ghcr.io/stack4ops/cibuilder:latest
```

### Disable Dynamic Loading in Production

```bash
# Lock embedded libraries (prevents external downloads)
docker run --rm \
  -e CIBUILD_RUN_CMD=build \
  -v /tmp/cibuilder.locked:/tmp/cibuilder.locked \
  ghcr.io/stack4ops/cibuilder:latest
```

### Build Custom Image

```bash
# Build with default settings
docker build -t my-cibuilder:latest .

# Build with custom cibuild version
docker build \
  --build-arg CIBUILDER_BIN_REF=v1.2.3 \
  -t my-cibuilder:latest \
  .

# Build for specific architecture
docker build \
  --build-arg TARGETARCH=arm64 \
  -t my-cibuilder:arm64 \
  .
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `CIBUILD_RUN_CMD` | Cibuild command to execute (check\|build\|test\|release\|all) | Required |
| `CIBUILDER_BIN_URL` | Custom cibuild download URL | https://github.com/stack4ops/cibuild/archive/refs/heads |
| `CIBUILDER_BIN_REF` | Custom cibuild version/branch/tag | main |
| `BUILDKITD_FLAGS` | Additional flags for buildkitd | -oci-worker-no-process-sandbox |
| `CIBUILDER_ROOTLESS_KIT` | Use rootlesskit wrapper (1\|0) | 1 |
| `DOCKER_CONFIG` | Docker configuration directory | /home/user/.docker |

## GitLab CI Example

```yaml
variables:
  CIBUILD_RUN_CMD: "all"

image: ghcr.io/stack4ops/cibuilder:latest

stages:
  - check
  - build
  - test
  - release

check:
  stage: check
  variables:
    CIBUILD_RUN_CMD: "check"

build:
  stage: build
  variables:
    CIBUILD_RUN_CMD: "build"

test:
  stage: test
  variables:
    CIBUILD_RUN_CMD: "test"

release:
  stage: release
  variables:
    CIBUILD_RUN_CMD: "release"
```

## Development and Debugging

### Testing Local cibuild Changes

```bash
# Mount local cibuild repository
docker run --rm \
  -e CIBUILD_RUN_CMD=build \
  -e CIBUILDER_BIN_URL=file:///path/to/local/cibuild \
  -e CIBUILDER_BIN_REF=main \
  ghcr.io/stack4ops/cibuilder:latest
```

### Debug Mode

```bash
# Disable rootlesskit for easier debugging
docker run --rm \
  -e CIBUILD_RUN_CMD=build \
  -e CIBUILDER_ROOTLESS_KIT=0 \
  -t -i \
  ghcr.io/stack4ops/cibuilder:latest
```

## Maintenance

This image builds and updates itself weekly in a scheduled cibuild pipeline with disabled cache (`use_cache=0`). This ties updates of embedded components to the base `buildkit:rootless` image release cycle.

## License

Apache-2.0

## Source Code

https://github.com/stack4ops/cibuilder