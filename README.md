[![cibuilder](https://github.com/stack4ops/cibuilder/actions/workflows/github-ci.yml/badge.svg?branch=main)](https://github.com/stack4ops/cibuilder/actions/workflows/github-ci.yml)
[![containerimage](https://img.shields.io/badge/image-digests-blue?logo=opencontainersinitiative)](https://github.com/stack4ops/cibuilder/releases/download/main-latest/digests.json)
[![Signed](https://img.shields.io/badge/cosign-signed-green?logo=sigstore&logoColor=white)](https://github.com/stack4ops/cibuilder/releases/download/main-latest/cert.json)


[![SBOM amd64](https://img.shields.io/badge/SBOM%20amd64-SPDX-blue?logo=json)](https://github.com/stack4ops/cibuilder/releases/download/main-latest/sbom-linux-amd64.spdx.json)
[![SBOM arm64](https://img.shields.io/badge/SBOM%20arm64-SPDX-blue?logo=json)](https://github.com/stack4ops/cibuilder/releases/download/main-latest/sbom-linux-arm64.spdx.json)


[![Provenance amd64](https://img.shields.io/badge/Provenance%20amd64-SLSA%20L2-blue?logo=json)](https://github.com/stack4ops/cibuilder/releases/download/main-latest/provenance-linux-amd64.slsa.json)
[![Provenance arm64](https://img.shields.io/badge/Provenance%20arm64-SLSA%20L2-blue?logo=json)](https://github.com/stack4ops/cibuilder/releases/download/main-latest/provenance-linux-arm64.slsa.json)


# cibuilder
-------------------
An image based on buildkit:rootless for building container images in a gitlab pipeline with embedded cibuild libs (https://github.com/stack4ops/cibuild).

## Customzations of buildkit:rootless
-------------------
* Adding binaries for pipeline run requirements:
    * **check**: regctl and jq
    * **build**: buildctl for direct communication with buildkitd endpoints over mTLS, docker-cli and buildx are also embedded 
    * **test**: kubectl and docker-cli are embedded for testing images in dind or kubernetes environments
    * **release**: regctl for creating the final multiarch image-index and adding additional tags, cosign for signing images

* Embedded cibuild libs: https://github.com/stack4ops/cibuild

* custom and fix cibuild_entrypoint (no extra command or arguments are appended):

    * Executing build run commands: `cibuild -r main|check|build|test|release` dependant on CIBUILD_RUN env
    * Dynamic loading of external cibuild libs (CIBUILDER_BIN_URL and CIBUILDER_BIN_REF env vars). This will override the embedded cibuild libs. It is useful for debugging and development. This can be switched of in production mode on custom gitlab-runner by mounting an empty volume /tmp/cibuilder.locked

* Adding ca certs for localregistry
 
## Notes
-------------------
* The image builds and updates itself in a scheduled cibuild pipeline every week with disabled cache (use_cache=0). I accept the trade-offs of tying updates of the embedded components to the version cycle of the base buildkit:rootless image.