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

The container image that powers [cibuild](https://github.com/stack4ops/cibuild) pipelines. Based on `moby/buildkit:rootless`, extended with all tools needed to run the full cibuild pipeline — check, build, test, and release — in a single image.

The image **builds and updates itself** using cibuild: a scheduled weekly pipeline rebuilds cibuilder from scratch, pulls the latest `buildkit:rootless` base, and re-embeds the current cibuild libs. No manual releases needed.

---

## What's Inside

`moby/buildkit:rootless` is the base. On top of it:

| Tool | Purpose |
|------|---------|
| `buildctl` | Direct communication with BuildKit daemons over mTLS (embedded in base) |
| `buildctl-daemonless.sh` | Runs an ephemeral BuildKit daemon inline — no separate daemon process needed |
| `docker` CLI + `buildx` plugin | `buildx` builds with `dockercontainer`, `remote`, and `kubernetes` drivers |
| `/kaniko/executor` | Daemonless image builds as root (copied from `martizih/kaniko`) |
| `regctl` | Multi-platform image index assembly, tag management, and signature cleanup |
| `cosign` | Keyless and key-based image signing and verification |
| `kubectl` | Running and inspecting test containers in Kubernetes |
| `jq` | JSON processing (layer comparison in the check run) |
| `git`, `curl`, `bash`, `openssh` | General pipeline tooling |

The [cibuild](https://github.com/stack4ops/cibuild) shell libs are embedded at `/home/cibuilder/bin/` and are invoked via the `cibuild_entrypoint.sh`.

CA certificates for the local lab registry (`localregistry.example.com`) are pre-installed, so the image works out of the box with the [cibuild local lab](https://github.com/stack4ops/cibuild/tree/main/installer).

---

## How It Builds Itself

The pipeline uses cibuilder to build cibuilder. This works because the image tag (`rootless`) is stable — the running cibuilder container and the freshly built one are different versions only during the brief build window.

The `cibuild.env` in this repo configures the self-build:

```sh
CIBUILD_BUILD_NATIVE=1        # build for the runner's own architecture
CIBUILD_BUILD_TAG=rootless     # stable tag, not a branch/commit tag
CIBUILD_BUILD_USE_CACHE=0      # always build fresh — picks up base image updates
CIBUILD_CHECK_ENABLED=1        # cancel if buildkit:rootless base hasn't changed
```

The check run compares the base image layers of the currently running `buildkit:rootless` against the last built cibuilder image. If nothing changed upstream, the pipeline is canceled. If the base has been updated, a full rebuild runs.

The release run tags the new image with:
- `rootless` — the stable pull tag
- `__DATETIME__` — a timestamped snapshot tag (e.g. `2025-04-14_09-00-00`)
- `__MINORTAG__` — the minor version tag of the `buildkit:rootless` base (resolved via `CIBUILD_RELEASE_MINOR_TAG_REGEX`)

The GitHub Actions pipeline builds natively on `ubuntu-latest` (amd64) and `ubuntu-24.04-arm` (arm64) in parallel, then assembles the multi-platform index in the release job.

---

## Entrypoint

The container is driven entirely by the `CIBUILD_RUN_CMD` environment variable. There are no positional arguments.

```sh
docker run --rm \
  -e CIBUILD_RUN_CMD=build \
  -v $(pwd):/workspace \
  ghcr.io/stack4ops/cibuilder:rootless
```

Supported values for `CIBUILD_RUN_CMD`: `check`, `build`, `test`, `release`, `all`.

The entrypoint wraps the run in `rootlesskit` by default (required for the embedded daemonless BuildKit). For kaniko builds, rootlesskit must be disabled:

```sh
CIBUILDER_ROOTLESS_KIT=0   # disable rootlesskit
CIBUILDER_USER="0:$(id -g)"  # run as root
CIBUILDER_PRIVILEGED=0       # no privileged container needed for kaniko
```

### Dynamic lib loading

At startup, `cibuild_entrypoint.sh` checks for `CIBUILDER_BIN_URL` and `CIBUILDER_BIN_REF`. If set, it downloads the specified version of the cibuild libs and replaces the embedded ones before running. This is used in the self-build pipeline (`CIBUILDER_BIN_REF: main`) to always run against the latest libs without rebuilding the image first.

```sh
# use a specific branch or tag of cibuild libs at runtime
CIBUILDER_BIN_REF=my-feature-branch
```

Dynamic loading can be blocked by mounting an empty directory at `/tmp/cibuilder.locked` — useful in production environments where the embedded libs should be the only ones used:

```sh
docker run --rm \
  -v /tmp/empty:/tmp/cibuilder.locked:ro \
  ...
```

When locked, pre/post scripts and test scripts are also blocked from executing.

---

## Usage in CI

### GitHub Actions

The pipeline uses the custom actions [`stack4ops/actions-cibuilder`](https://github.com/stack4ops/actions-cibuilder) and [`stack4ops/actions-cibuilder-dind`](https://github.com/stack4ops/actions-cibuilder-dind) (the DinD variant is used for the test run):

```yaml
- uses: stack4ops/actions-cibuilder@v1
  with:
    run_cmd: build
    bin_ref: main
```

### GitLab CI

The image is used directly as the job image. `CIBUILD_RUN_CMD` is set per job via `variables`, and the `script` block is just `/bin/true` — all logic runs in the entrypoint:

```yaml
image: ghcr.io/stack4ops/cibuilder:rootless

build:
  variables:
    CIBUILD_RUN_CMD: build
  script:
    - /bin/true
```

For native multi-platform builds, define one job per architecture with matching runner tags:

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

## Local Development

To use cibuilder locally or to develop and test cibuild itself, see the [cibuild local lab](https://github.com/stack4ops/cibuild/tree/main/installer). It provides a fully pre-configured environment including DinD, a local registry, a k3d Kubernetes cluster, and all required service accounts — installed with a single script.