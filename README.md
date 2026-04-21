[![cibuilder](https://github.com/stack4ops/cibuilder/actions/workflows/github-ci.yml/badge.svg?branch=main)](https://github.com/stack4ops/cibuilder/actions/workflows/github-ci.yml)
[![License](https://img.shields.io/badge/license-Apache%202.0-green)](LICENSE)
[![Shell](https://img.shields.io/badge/shell-POSIX%20sh-lightgrey?logo=gnu-bash)](https://github.com/stack4ops/cibuild)
[![Platforms](https://img.shields.io/badge/platforms-linux%2Famd64%20%7C%20linux%2Farm64-orange?logo=linux)](https://github.com/stack4ops/cibuilder/releases/download/main-latest/digests.json)

[![containerimage](https://img.shields.io/badge/image-digests-blue?logo=opencontainersinitiative)](https://github.com/stack4ops/cibuilder/releases/download/main-latest/digests.json)
[![Signed](https://img.shields.io/badge/cosign-signed-green?logo=sigstore&logoColor=white)](https://github.com/stack4ops/cibuilder/releases/download/main-latest/cert.json)
[![SBOM amd64](https://img.shields.io/badge/SBOM%20amd64-SPDX-blue?logo=json)](https://github.com/stack4ops/cibuilder/releases/download/main-latest/sbom-linux-amd64.spdx.json)
[![SBOM arm64](https://img.shields.io/badge/SBOM%20arm64-SPDX-blue?logo=json)](https://github.com/stack4ops/cibuilder/releases/download/main-latest/sbom-linux-arm64.spdx.json)
[![Provenance amd64](https://img.shields.io/badge/Provenance%20amd64-SLSA%20L2-blue?logo=json)](https://github.com/stack4ops/cibuilder/releases/download/main-latest/provenance-linux-amd64.slsa.json)
[![Provenance arm64](https://img.shields.io/badge/Provenance%20arm64-SLSA%20L2-blue?logo=json)](https://github.com/stack4ops/cibuilder/releases/download/main-latest/provenance-linux-arm64.slsa.json)

# cibuilder

The container image that powers [cibuild](https://github.com/stack4ops/cibuild) pipelines. Based on `debian:13-slim` (trixie), extended with all tools needed to run the full cibuild pipeline — check, build, test, and release.

The image comes in **focused variants** — each containing only the tools required for its build backend. A `full` variant combines all backends for local lab use.

---

## Image Variants

| Tag | Base | Build Backend | Use Case |
|-----|------|---------------|----------|
| `base` | debian:13-slim | — | Foundation only, no build backend |
| `buildctl` | base | buildctl + rootlesskit | Default CI — daemonless BuildKit |
| `buildx` | base | docker CLI + buildx | Docker-based builds |
| `kaniko` | base | kaniko executor | Rootless Kubernetes builds |
| `nix` | base + nix | nix build | Declarative, reproducible image builds |
| `full` | base + all | all of the above | Local lab / development |

All variants share the same `debian:13-slim` foundation and common tooling. Base image and tool versions are pinned and updated automatically via [Renovate](renovate.json).

> **ZenDIS alignment:** The base image can be swapped to `registry.opencode.de/oci-community/images/zendis/debian` for BSI-compliant deployments. Only the `FROM` line changes — everything else stays the same.

---

## What's Inside

All variants include:

| Tool | Purpose |
|------|---------|
| `regctl` | Multi-platform image index assembly, tag management, signature cleanup |
| `cosign` | Keyless and key-based image signing and verification |
| `trivy` | SBOM generation (SPDX/CycloneDX) and CVE scanning |
| `kubectl` | Running and inspecting test containers in Kubernetes |
| `jq` | JSON processing |
| `git`, `curl`, `bash`, `openssh` | General pipeline tooling |

Additional tools per variant:

| Variant | Extra Tools |
|---------|-------------|
| `buildctl` | `buildkitd`, `buildctl`, `rootlesskit`, `newuidmap`, `newgidmap`, `buildctl-daemonless.sh` |
| `buildx` | `docker` CLI, `docker-buildx` plugin |
| `kaniko` | `/kaniko/executor` |
| `nix` | Nix single-user installation, `nix` CLI |
| `full` | All of the above |

The [cibuild](https://github.com/stack4ops/cibuild) shell libs are embedded at `/home/cibuilder/bin/` and invoked via `cibuild_entrypoint.sh`.

CA certificates for the local lab registry (`localregistry.example.com`) are pre-installed, so the image works out of the box with the [cibuild local lab](https://github.com/stack4ops/cibuild/tree/main/installer).

---

## Entrypoint

The container is driven entirely by the `CIBUILD_RUN_CMD` environment variable. There are no positional arguments.

```sh
docker run --rm \
  -e CIBUILD_RUN_CMD=build \
  -v $(pwd):/workspace \
  ghcr.io/stack4ops/cibuilder:buildctl
```

Supported values for `CIBUILD_RUN_CMD`: `check`, `build`, `test`, `release`, `all`.

### buildctl (default)

The `buildctl` variant runs with rootlesskit by default — required for the embedded daemonless BuildKit:

```sh
CIBUILDER_ROOTLESS_KIT=1
CIBUILDER_USER="1000:$(id -g)"
CIBUILDER_PRIVILEGED=1
```

### kaniko

The `kaniko` variant runs as root without rootlesskit:

```sh
CIBUILDER_ROOTLESS_KIT=0
CIBUILDER_USER="0:$(id -g)"
CIBUILDER_PRIVILEGED=0
```

### nix

The `nix` variant runs as `cibuilder` (uid 1000) without rootlesskit. Sandbox mode is auto-detected at runtime:

```sh
CIBUILDER_ROOTLESS_KIT=0    # nix needs no kernel features
CIBUILDER_USER="1000:$(id -g)"
CIBUILDER_PRIVILEGED=0
```

Configure the nix build backend in your repo's `cibuild.env`:

```sh
CIBUILD_BUILD_CLIENT=nix
CIBUILD_NIX_FLAKE_ATTR=default        # packages.<system>.default in flake.nix
CIBUILD_BUILD_SBOM_BACKEND=trivy      # SBOM via trivy after build
CIBUILD_NIX_CACHE_URL=https://...     # optional: Attic/Cachix cache URL
CIBUILD_NIX_CACHE_TOKEN=...           # optional: cache auth token
```

### Dynamic lib loading

At startup, `cibuild_entrypoint.sh` checks for `CIBUILDER_BIN_URL` and `CIBUILDER_BIN_REF`. If set, it downloads the specified version of the cibuild libs and replaces the embedded ones before running:

```sh
CIBUILDER_BIN_REF=my-feature-branch
```

Dynamic loading can be blocked by mounting an empty directory at `/tmp/cibuilder.locked`:

```sh
docker run --rm \
  -v /tmp/empty:/tmp/cibuilder.locked:ro \
  ...
```

---

## SBOM and Scanning

All variants include `trivy` for backend-independent SBOM generation and CVE scanning. Configure in `cibuild.env`:

```sh
CIBUILD_BUILD_SBOM=1
CIBUILD_BUILD_SBOM_BACKEND=trivy       # trivy (all backends) or buildkit (buildctl/buildx only)
CIBUILD_BUILD_SBOM_FORMAT=spdx-json    # spdx-json or cyclonedx-json
```

SBOMs are written to `$CIBUILD_OUTPUT_DIR/sbom-<platform>.spdx.json` and published as release assets.

---

## Usage in CI

### GitHub Actions

```yaml
- uses: stack4ops/actions-cibuilder@v1
  with:
    run_cmd: build
    bin_ref: main
```

For the test run with Docker backend, use the DinD variant:

```yaml
- uses: stack4ops/actions-cibuilder-dind@v1
  with:
    run_cmd: test
```

### GitLab CI

The image is used directly as the job image. `CIBUILD_RUN_CMD` is set per job via `variables`, and the `script` block is just `/bin/true` — all logic runs in the entrypoint:

```yaml
image: ghcr.io/stack4ops/cibuilder:buildctl

build:
  variables:
    CIBUILD_RUN_CMD: build
  script:
    - /bin/true
```

For native multi-platform builds:

```yaml
build-amd64:
  variables:
    CIBUILD_RUN_CMD: build
  script:
    - /bin/true
  tags:
    - saas-linux-medium-amd64

build-arm64:
  variables:
    CIBUILD_RUN_CMD: build
  script:
    - /bin/true
  tags:
    - saas-linux-medium-arm64
```

The test run requires a DinD service when `TEST_BACKEND=docker`:

```yaml
test:
  services:
    - name: docker:dind
      alias: docker
  variables:
    CIBUILD_RUN_CMD: test
  script:
    - /bin/true
```

---

## Building Locally (wip documentation...)

To build a specific variant locally against the [cibuild local lab](https://github.com/stack4ops/cibuild/tree/main/installer) registry:

```sh
# create a builder in the lab network (once)
docker buildx inspect cibuilder-local > /dev/null 2>&1 || \
  docker buildx create \
    --name cibuilder-local \
    --driver docker-container \
    --driver-opt network=cibuilder-net \
    --config ./buildkitd.local.toml

docker buildx use cibuilder-local

# build a specific target
docker buildx build \
  --target full \
  --platform linux/amd64 \
  --tag localregistry.example.com:5000/stack4ops/cibuilder:full \
  --push \
  .
```

Build all targets at once:

```sh
for target in base nix buildctl buildx kaniko full; do
  docker buildx build \
    --target ${target} \
    --platform linux/amd64 \
    --tag localregistry.example.com:5000/stack4ops/cibuilder:${target} \
    --push \
    .
done
```

---

## Local Development

To use cibuilder locally or to develop and test cibuild itself, see the [cibuild local lab](https://github.com/stack4ops/cibuild/tree/main/installer). It provides a fully pre-configured environment including DinD, a local registry, an Attic Nix binary cache, a k3d Kubernetes cluster, and all required service accounts — installed with a single script.