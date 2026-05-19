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
| `build-buildctl` | `build` | base + buildctl + rootlesskit + trivy + cosign | Default CI — daemonless BuildKit |
| `build-buildx` | `build` | base + docker CLI + buildx + trivy + cosign | Docker-based builds |
| `build-nix` | `build` | base + nix + regctl + cosign | Declarative, reproducible builds via Nix flakes |
| `build-kaniko` | `build` | base + kaniko executor | Rootless Kubernetes builds |
| `test-docker` | `test` | base + docker CLI | Test with Docker backend |
| `test-k8s` | `test` | base + kubectl | Test with Kubernetes backend |
| `release` | `release` | base + regctl + cosign + trivy | Index assembly, signing, SBOM conversion |
| `update-caches` | `update-caches` | base + trivy | Scheduled cache updates (trivy DB) |
| `all` | `all` | everything | All runs in one — local lab or simple CI |

Each image knows what it does — no `CIBUILD_RUN_CMD` needed in CI. The `all` variant runs all runs sequentially in a single job — the simplest CI setup, recommended unless native multi-arch builds or job-level isolation is required. It accepts `-e CIBUILD_RUN_CMD=build` to run a single step for debugging.

All variants share the same `debian:13-slim` foundation. Base image and tool versions are pinned and updated automatically via [Renovate](renovate.json).

> **ZenDIS alignment:** The base image can be swapped to `registry.opencode.de/oci-community/images/zendis/debian` for BSI-compliant deployments. Only the `FROM` line changes — everything else stays the same.
>
> **K8s-friendly:** `base`, `check`, `build-buildctl`, `build-nix`, `build-kaniko`, `release` contain no docker CLI.

---

## Supply Chain — Build Run

Every platform image built with cibuilder gets a complete set of supply chain artifacts generated and signed **immediately after the build**, in the same build run. These artifacts are pushed as OCI referrers to the target registry and cryptographically anchored to the platform image digest.

### What gets generated per platform

| Artifact | OCI Media Type | Tool |
|----------|----------------|------|
| CycloneDX SBOM | `application/vnd.cyclonedx+json` | trivy |
| CVE vulnerability report | `application/vnd.trivy.vuln+json` | trivy |
| SLSA provenance | `application/vnd.slsa.provenance+json` | buildctl / buildx |
| Cosign signature | OCI referrer | cosign |

For `build_client=nix`, SBOM and CVE report are generated by the Nix toolchain (`bombon` + `vulnxscan`) and pushed as the same referrer types — the trivy step is skipped. For `build_client=kaniko`, supply chain artifacts are generated in the release run only.

### Artifact lock files

After each platform build, cibuild writes an `artifact-lock.<platform_name>.json` file to the repository root and commits it back to the branch. This file records the exact digests of the platform image and all its supply chain referrers — creating a cryptographic anchor that ties every artifact to the immutable image digest.

```json
{
  "platform":      "linux/amd64",
  "platform_name": "linux-amd64",
  "image":         "ghcr.io/stack4ops/cibuilder",
  "build_tag":     "main",
  "image_digest":  "sha256:abc123...",
  "referrers": {
    "sbom":        "sha256:def456...",
    "vuln":        "sha256:ghi789...",
    "provenance":  "sha256:jkl012..."
  },
  "image_sig":     "sha256:mno345...",
  "build_client":  "buildctl",
  "source_commit": "a1b2c3d4...",
  "built_at":      "2024-11-15T10:30:00Z"
}
```

The lock file is used by subsequent runs:

- **Test run** — reads `image_digest` from the lock file and verifies the cosign signature before running any tests. Tests always run against the exact signed digest, never against a tag. Disable with `CIBUILD_TEST_COSIGN_VERIFY_BUILD_ARTEFACTS=0`.
- **Release run** — reads platform digests from all lock files to assemble the multi-platform index, and re-verifies all cosign signatures before proceeding. This guarantees the released index references exactly what was built and signed — independent of tag state in the registry. Disable with `CIBUILD_RELEASE_COSIGN_VERIFY_BUILD_ARTEFACTS=0`.

The lock file is plain JSON committed to the repository, making all artifact digests available to external compliance tools without registry access:

- **SBOM consumers** (OWASP Dependency-Track, DevGuard) — fetch the CycloneDX SBOM by digest via `referrers.sbom`
- **CVE / VEX pipelines** — fetch the vulnerability report via `referrers.vuln`
- **SARIF / audit dashboards** — correlate `image_digest` + `source_commit` + `built_at`
- **Sigstore verification** — independently verify the signature via `image_sig`

### Release run SBOM conversion

The release run converts the CycloneDX SBOM referrer (produced in the build run) into additional formats and writes them to `$CIBUILD_OUTPUT_DIR` as release artifacts:

```
sbom-linux-amd64.spdx.json       # SPDX — GitHub, OpenChain, compliance tools
sbom-linux-amd64.cdx.json        # CycloneDX — OWASP Dependency-Track, DevGuard
sbom-linux-arm64.spdx.json
sbom-linux-arm64.cdx.json
vuln-linux-amd64.json             # CVE report (if CIBUILD_RELEASE_VULN=1)
vuln-linux-arm64.json
provenance-linux-amd64.slsa.json  # SLSA provenance (buildctl/buildx only)
provenance-linux-arm64.slsa.json
digests.json                      # multi-platform image index digests
cert.json                         # cosign keyless certificate
```

Configure via `cibuild.env`:

```sh
# build run — SBOM + CVE generated per platform immediately after build
CIBUILD_BUILD_SBOM=1                               # default: 1
CIBUILD_BUILD_SBOM_FORMATS=cyclonedx              # default: cyclonedx
CIBUILD_BUILD_VULN=1                               # default: 1

# release run — SBOM conversion + optional additional CVE scan
CIBUILD_RELEASE_SBOM=1                             # default: 1
CIBUILD_RELEASE_SBOM_FORMATS=spdx-json,cyclonedx  # default: both
CIBUILD_RELEASE_VULN=0                             # default: 0 (already done in build run)
CIBUILD_RELEASE_VULN_FORMAT=json                   # default: json
```

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
| `newuidmap`, `newgidmap` | UID/GID mapping for rootless operation (via `uidmap` apt package + `setcap`) |
| `buildkit-qemu-*` | Built-in QEMU helpers for cross-arch builds — no binfmt_misc needed |
| `trivy` | CycloneDX SBOM + CVE report generated as OCI referrers after each platform build |
| `cosign` | Signs platform image + all referrers immediately after build |

### `build-buildx`

| Tool | Purpose |
|------|---------|
| `docker` CLI | Docker client |
| `docker-buildx` plugin | buildx build backend |
| `trivy` | CycloneDX SBOM + CVE report generated as OCI referrers after each platform build |
| `cosign` | Signs platform image + all referrers immediately after build |

### `build-nix`

| Tool | Purpose |
|------|---------|
| `nix` | Single-user Nix installation with flakes enabled |
| `regctl` | Pushes Nix-generated OCI tar to registry |
| `cosign` | Signs platform image + all referrers immediately after build |

The `build-nix` variant ships Nix pre-installed at `/nix` with flakes and the `nix-command` experimental feature enabled. It builds OCI images directly from a `flake.nix` using `nixpkgs.dockerTools` — no Dockerfile, no BuildKit daemon, no `--privileged` flag. For Nix builds, SBOM and CVE report are generated by the Nix toolchain (`bombon` + `vulnxscan`) — trivy is not used. Sandbox mode is auto-detected at runtime via `ROOTLESSKIT_PID`.

Configure in your repo's `cibuild.env`:

```sh
CIBUILD_BUILD_CLIENT=nix
CIBUILD_NIX_FLAKE_ATTR=default          # packages.<system>.default in flake.nix
CIBUILD_NIX_CACHE_URL=https://...       # optional: Attic/Cachix binary cache URL
CIBUILD_NIX_CACHE_TOKEN=...             # optional: cache auth token
```

### `build-kaniko`

| Tool | Purpose |
|------|---------|
| `/kaniko/executor` | Daemonless image builds as root |

> Kaniko does not support cosign signing or trivy SBOM generation in the build run. Supply chain artifacts for kaniko builds are generated in the release run only.

### `test-docker`

| Tool | Purpose |
|------|---------|
| `docker` CLI | `docker run/inspect/logs` for test assertions |

The test run reads the platform image digest from the artifact lock file and verifies the cosign signature before executing any tests. Set `CIBUILD_TEST_COSIGN_VERIFY_BUILD_ARTEFACTS=0` to skip.

### `test-k8s`

| Tool | Purpose |
|------|---------|
| `kubectl` | Run and inspect test containers in Kubernetes |

### `release`

| Tool | Purpose |
|------|---------|
| `regctl` | Multi-platform index assembly, tag management, referrer copy |
| `cosign` | Verifies build artifact signatures, signs the final image index |
| `trivy` | Converts CycloneDX SBOM referrer to SPDX + writes release artifacts |

The release run reads platform digests from the artifact lock files and verifies all cosign signatures before assembling the index. Set `CIBUILD_RELEASE_COSIGN_VERIFY_BUILD_ARTEFACTS=0` to skip.

### `update-caches`

| Tool | Purpose |
|------|---------|
| `trivy` | Downloads and refreshes the vulnerability DB into a mounted cache volume |

The [cibuild](https://github.com/stack4ops/cibuild) shell libs are embedded at `/home/cibuilder/bin/` and invoked via `cibuild_entrypoint.sh`.

CA certificates for the local lab registry (`localregistry.example.com`) are pre-installed so all variants work out of the box with the [cibuild local lab](https://github.com/stack4ops/cibuild/tree/main/installer).

---

## Entrypoint

Each image has `CIBUILD_RUN_CMD` hardcoded — just run it:

```sh
# check run
docker run --rm -v $(pwd):/repo -w /repo \
  ghcr.io/stack4ops/cibuilder:check

# build run (buildctl — daemonless, rootless)
docker run --rm --security-opt seccomp=unconfined \
  -v $(pwd):/repo -w /repo \
  ghcr.io/stack4ops/cibuilder:build-buildctl

# build run (nix — no daemon, no --privileged)
docker run --rm -v $(pwd):/repo -w /repo \
  ghcr.io/stack4ops/cibuilder:build-nix

# release run
docker run --rm -v $(pwd):/repo -w /repo \
  ghcr.io/stack4ops/cibuilder:release

# update-caches run (scheduled cache refresh)
docker run --rm \
  -v cibuilder-trivy-cache:/home/cibuilder/.cache/trivy \
  ghcr.io/stack4ops/cibuilder:update-caches
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

build-nix-amd64:
  image: ghcr.io/stack4ops/cibuilder:build-nix
  script: [/bin/true]
  variables:
    CIBUILD_BUILD_CLIENT: nix
    CIBUILD_NIX_FLAKE_ATTR: default
  tags: [saas-linux-medium-amd64]

test:
  image: ghcr.io/stack4ops/cibuilder:test-docker
  services:
    - name: docker:dind
      alias: docker
  script: [/bin/true]

release:
  image: ghcr.io/stack4ops/cibuilder:release
  script: [/bin/true]

update-caches:
  image: ghcr.io/stack4ops/cibuilder:update-caches
  script: [/bin/true]
  rules:
    - if: $CI_PIPELINE_SOURCE == "schedule"
```

---

## Building Locally

Use `build-local.sh` to build all targets into the local Docker image store:

```sh
# build all targets
./build-local.sh

# build a single target
./build-local.sh release
./build-local.sh update-caches
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