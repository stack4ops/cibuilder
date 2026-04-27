[![cibuilder](https://github.com/stack4ops/cibuilder/actions/workflows/github-ci.yml/badge.svg?branch=main)](https://github.com/stack4ops/cibuilder/actions/workflows/github-ci.yml)
[![License](https://img.shields.io/badge/license-Apache%202.0-green)](LICENSE)
[![Shell](https://img.shields.io/badge/shell-POSIX%20sh-lightgrey?logo=gnu-bash)](https://github.com/stack4ops/cibuild)
[![Platforms](https://img.shields.io/badge/platforms-linux%2Famd64%20%7C%20linux%2Farm64-orange?logo=linux)](https://github.com/stack4ops/cibuilder/releases/download/main-latest/digests.json)

[![containerimage](https://img.shields.io/badge/image-digests-blue?logo=opencontainersinitiative)](https://github.com/stack4ops/cibuilder/releases/download/main-latest/digests.json)
[![Signed](https://img.shields.io/badge/cosign-signed-green?logo=sigstore&logoColor=white)](https://github.com/stack4ops/cibuilder/releases/download/main-latest/cert.json)
[![SBOM amd64 SPDX](https://img.shields.io/badge/SBOM%20amd64-SPDX-blue?logo=json)](https://github.com/stack4ops/cibuilder/releases/download/main-latest/sbom-linux-amd64.spdx.json)
[![SBOM amd64 CycloneDX](https://img.shields.io/badge/SBOM%20amd64-CycloneDX-blue?logo=json)](https://github.com/stack4ops/cibuilder/releases/download/main-latest/sbom-linux-amd64.cdx.json)
[![SBOM arm64 SPDX](https://img.shields.io/badge/SBOM%20arm64-SPDX-blue?logo=json)](https://github.com/stack4ops/cibuilder/releases/download/main-latest/sbom-linux-arm64.spdx.json)
[![SBOM arm64 CycloneDX](https://img.shields.io/badge/SBOM%20arm64-CycloneDX-blue?logo=json)](https://github.com/stack4ops/cibuilder/releases/download/main-latest/sbom-linux-arm64.cdx.json)
[![Provenance amd64](https://img.shields.io/badge/Provenance%20amd64-SLSA%20L2-blue?logo=json)](https://github.com/stack4ops/cibuilder/releases/download/main-latest/provenance-linux-amd64.slsa.json)
[![Provenance arm64](https://img.shields.io/badge/Provenance%20arm64-SLSA%20L2-blue?logo=json)](https://github.com/stack4ops/cibuilder/releases/download/main-latest/provenance-linux-arm64.slsa.json)

# cibuilder

The container image that powers [cibuild](https://github.com/stack4ops/cibuild) pipelines. Based on `debian:13-slim` (trixie), it comes in **run-oriented variants** — each image contains exactly the tools needed for one cibuild run and has its `CIBUILD_RUN_CMD` hardcoded. The `all` variant combines everything for local lab use.

---

## Image Variants

| Tag | `CIBUILD_RUN_CMD` | Contents | Use Case |
|-----|-------------------|----------|----------|
| `base` | — | curl, git, jq, openssh | Minimal foundation |
| `check` | `check` | base + regctl | Layer diff against registry |
| `build-buildctl` | `build` | base + buildctl + rootlesskit | Default CI — daemonless BuildKit |
| `build-buildx` | `build` | base + docker CLI + buildx | Docker-based builds |
| `build-nix` | `build` | base + nix | Declarative, reproducible builds |
| `build-kaniko` | `build` | base + kaniko executor | Rootless Kubernetes builds |
| `test-docker` | `test` | base + docker CLI | Test with Docker backend |
| `test-k8s` | `test` | base + kubectl | Test with Kubernetes backend |
| `release` | `release` | base + regctl + cosign + trivy | Index assembly, signing, SBOM |
| `all` | `all` | everything | Local lab / development |

Each image knows what it does — no `CIBUILD_RUN_CMD` needed in CI. The `all` variant accepts an override via `-e CIBUILD_RUN_CMD=build` for debugging.

All variants share the same `debian:13-slim` foundation. Base image and tool versions are pinned and updated automatically via [Renovate](renovate.json).

> **ZenDIS alignment:** The base image can be swapped to `registry.opencode.de/oci-community/images/zendis/debian` for BSI-compliant deployments. Only the `FROM` line changes — everything else stays the same.
>
> **K8s-friendly:** `base`, `check`, `build-buildctl`, `build-nix`, `build-kaniko`, `release` contain no docker CLI.

---

## What's Inside

### All variants

| Tool | Purpose |
|------|---------|
| `curl`, `git`, `jq`, `openssh` | General pipeline tooling |

### `check`

| Tool | Purpose |
|------|---------|
| `regctl` | Layer diff: compares base image layers against last built image |

### `build-buildctl`

| Tool | Purpose |
|------|---------|
| `buildkitd`, `buildctl` | BuildKit daemon and client |
| `rootlesskit` | User namespace setup for daemonless BuildKit |
| `buildctl-daemonless.sh` | Runs ephemeral BuildKit inline — no separate daemon |
| `runc` | OCI worker for BuildKit (via `runc` apt package) |
| `fuse3`, `fuse-overlayfs` | Overlay filesystem for BuildKit snapshotter |
| `binfmt` QEMU helpers | Cross-architecture builds (e.g. arm64 on amd64 runner) |
| `newuidmap`, `newgidmap` | UID/GID mapping for rootless operation (via `uidmap` apt package + `setcap`) |
| `netcat-openbsd` | Port reachability checks in the test run |

### `build-buildx`

| Tool | Purpose |
|------|---------|
| `docker` CLI | Docker client |
| `docker-buildx` plugin | buildx build backend |

### `build-nix`

| Tool | Purpose |
|------|---------|
| `nix` | Nix single-user installation with flakes enabled |

### `build-kaniko`

| Tool | Purpose |
|------|---------|
| `/kaniko/executor` | Daemonless image builds as root |

### `test-docker`

| Tool | Purpose |
|------|---------|
| `docker` CLI | `docker run/inspect/logs` for test assertions |

### `test-k8s`

| Tool | Purpose |
|------|---------|
| `kubectl` | Run and inspect test containers in Kubernetes |

### `release`

| Tool | Purpose |
|------|---------|
| `regctl` | Multi-platform index assembly, tag management |
| `cosign` | Keyless and key-based image signing |
| `trivy` | SBOM (SPDX + CycloneDX) and CVE scanning |

The [cibuild](https://github.com/stack4ops/cibuild) shell libs are embedded at `/home/cibuilder/bin/` and invoked via `cibuild_entrypoint.sh`.

CA certificates for the local lab registry (`localregistry.example.com`) are pre-installed so all variants work out of the box with the [cibuild local lab](https://github.com/stack4ops/cibuild/tree/main/installer).

---

## Entrypoint

Each image has `CIBUILD_RUN_CMD` hardcoded — just run it:

```sh
# check run
docker run --rm -v $(pwd):/repo -w /repo \
  ghcr.io/stack4ops/cibuilder:check

# build run (buildctl)
docker run --rm --privileged -v $(pwd):/repo -w /repo \
  ghcr.io/stack4ops/cibuilder:build-buildctl

# release run
docker run --rm -v $(pwd):/repo -w /repo \
  ghcr.io/stack4ops/cibuilder:release
```

Override for the `all` variant:

```sh
docker run --rm -e CIBUILD_RUN_CMD=build \
  ghcr.io/stack4ops/cibuilder:all
```

### build-buildctl

Runs with rootlesskit — required for the embedded daemonless BuildKit:

```sh
CIBUILDER_ROOTLESS_KIT=1
CIBUILDER_USER="1000:$(id -g)"
CIBUILDER_PRIVILEGED=0
```

> rootlesskit runs as uid 1000 with `subuid`/`subgid` configured — no `--privileged` needed. The runner must support user namespaces (`/proc/sys/kernel/unprivileged_userns_clone=1`).

### build-nix

Runs as `cibuilder` (uid 1000) without rootlesskit. Sandbox mode is auto-detected at runtime via `ROOTLESSKIT_PID`:

```sh
CIBUILDER_ROOTLESS_KIT=0
CIBUILDER_USER="1000:$(id -g)"
CIBUILDER_PRIVILEGED=0
```

Configure in your repo's `cibuild.env`:

```sh
CIBUILD_BUILD_CLIENT=nix
CIBUILD_NIX_FLAKE_ATTR=default        # packages.<system>.default in flake.nix
CIBUILD_NIX_CACHE_URL=https://...     # optional: Attic/Cachix binary cache URL
CIBUILD_NIX_CACHE_TOKEN=...           # optional: cache auth token
```

### build-kaniko

Runs as root without rootlesskit:

```sh
CIBUILDER_ROOTLESS_KIT=0
CIBUILDER_USER="0:$(id -g)"
CIBUILDER_PRIVILEGED=0
```

### Dynamic lib loading

At startup, `cibuild_entrypoint.sh` checks for `CIBUILDER_BIN_REF`. If set, it downloads that version of the cibuild libs and replaces the embedded ones before running — useful for lib development without rebuilding the image:

```sh
CIBUILDER_BIN_REF=my-feature-branch
```

Block dynamic loading by mounting an empty directory at `/tmp/cibuilder.locked`:

```sh
docker run --rm -v /tmp/empty:/tmp/cibuilder.locked:ro ...
```

---

## SBOM and Release Artifacts

SBOM generation and CVE scanning always happen in the `release` run via `trivy`. Both SPDX and CycloneDX formats are written by default:

```
sbom-linux-amd64.spdx.json       # SPDX — GitHub, OpenChain, compliance tools
sbom-linux-amd64.cdx.json        # CycloneDX — OWASP Dependency-Track, DevGuard
sbom-linux-arm64.spdx.json
sbom-linux-arm64.cdx.json
vuln-linux-amd64.json             # CVE report (optional, trivy --scanners vuln)
vuln-linux-arm64.json
provenance-linux-amd64.slsa.json  # SLSA provenance (buildctl/buildx only)
provenance-linux-arm64.slsa.json
digests.json                      # multi-platform image index digests
cert.json                         # cosign keyless certificate
```

Configure via `cibuild.env`:

```sh
CIBUILD_RELEASE_SBOM=1                          # default: 1
CIBUILD_RELEASE_SBOM_FORMATS=spdx-json,cyclonedx  # default: both
CIBUILD_RELEASE_VULN=1                          # default: 1
CIBUILD_RELEASE_VULN_FORMAT=json                # default: json
CIBUILD_RELEASE_UPLOAD_SUPPLY_CHAIN_ARTIFACTS=package  # GitLab: upload to Generic Package Registry
```

---

## Usage in CI

### GitHub Actions

Each run uses the matching image variant — no `CIBUILD_RUN_CMD` needed:

```yaml
- uses: stack4ops/actions-cibuilder@v1
  env:
    CIBUILDER_REF: check

- uses: stack4ops/actions-cibuilder@v1
  env:
    CIBUILDER_REF: build-buildctl

- uses: stack4ops/actions-cibuilder-dind@v1
  env:
    CIBUILDER_REF: test-docker

- uses: stack4ops/actions-cibuilder@v1
  env:
    CIBUILDER_REF: release
```

### GitLab CI

The image tag determines what runs — `script: [/bin/true]` is all that's needed:

```yaml
check:
  image: ghcr.io/stack4ops/cibuilder:check
  script: [/bin/true]

build-amd64:
  image: ghcr.io/stack4ops/cibuilder:build-buildctl
  script: [/bin/true]
  tags: [saas-linux-medium-amd64]

build-arm64:
  image: ghcr.io/stack4ops/cibuilder:build-buildctl
  script: [/bin/true]
  tags: [saas-linux-medium-arm64]

test:
  image: ghcr.io/stack4ops/cibuilder:test-docker
  services:
    - name: docker:dind
      alias: docker
  script: [/bin/true]

release:
  image: ghcr.io/stack4ops/cibuilder:release
  script: [/bin/true]
```

---

## Building Locally

Use `build-local.sh` to build all targets into the local Docker image store:

```sh
# build all targets
./build-local.sh

# build a single target
./build-local.sh release
./build-local.sh build-nix
```

This uses `--load` to write directly into the local Docker image store as `localhost/cibuilder:<target>`. No registry push needed.

Set in `~/.config/cibuild/.env` to use locally built images:

```sh
CIBUILDER_IMAGE=localhost/cibuilder
CIBUILDER_REF=all
```

To use a buildx builder with lab network access (for pushing to the local registry):

```sh
docker buildx inspect cibuilder-local > /dev/null 2>&1 || \
  docker buildx create \
    --name cibuilder-local \
    --driver docker-container \
    --driver-opt network=cibuilder-net \
    --config ./bin/lib/res/buildkitd.local.toml

docker buildx use cibuilder-local

docker buildx build \
  --target release \
  --platform linux/amd64 \
  --tag localregistry.example.com:5000/stack4ops/cibuilder:release \
  --push \
  .
```

---

## Local Development

To develop and test cibuild itself, see the [cibuild local lab](https://github.com/stack4ops/cibuild/tree/main/installer). It provides a fully pre-configured environment including DinD, a local registry, an Attic Nix binary cache, a k3d Kubernetes cluster, and all required service accounts — installed with a single script.