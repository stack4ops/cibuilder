# cibuilder
-------------------
An image based on buildkit:rootless for building container images in a gitlab pipeline with embedded cibuild libs (https://gitlab.com/stack4ops/public/cibuild).

## Image Customzing
-------------------
* Pipeline run requirements:
    * **check**: regctl and jq
    * **build**: buildctl for direct communication with buildkitd endpoints over mTLS, also docker-cli is embedded 
    * **test**: kubectl and docker-cli are embedded for testing images in dind or kubernetes environments
    * **release**: regctl for creating the final multiarch image-index and adding additional tags

* Embedded cibuild libs: https://gitlab.com/stack4ops/public/cibuild

* custom and fix cibuild_entrypoint (no extra command or arguments are appended):

    * Executing build run commands: `cibuild -r main|check|build|test|release` dependant on CIBUILD_RUN env
    * Dynamic loading of external cibuild libs (CIBUILDER_BIN_URL and CIBUILDER_BIN_REF env vars). This will override the embedded cibuild libs. It is useful for debugging and development. This can be switched of in production mode on custom gitlab-runner by mounting an empty volume /tmp/cibuilder.locked

* Adding ca certs for localregistry
 
## Notes
-------------------
* The image builds and updates itself in a scheduled cibuild pipeline every week with disabled cache (use_cache=0). I accept the trade-offs of tying updates of the embedded components to the version cycle of the base buildkit:rootless image.