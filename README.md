# cibuilder (deprecated)
-------------------
An image based on docker:cli for building container images in a gitlab pipeline with embedded cibuild libs (https://gitlab.com/stack4ops/public/cibuild).

## Image Customzing
-------------------
* Running as non-root

* Pipeline run requirements:
    * **check**: regctl and jq
    * **build**: buildctl for direct communication with buildkitd endpoints over mTLS
    * **test**: kubectl for testing images in kubernetes environments
    * **deploy**: regctl for image copy (re-tagging)

* Embedded cibuild libs: https://gitlab.com/stack4ops/public/cibuild

* custom and fix cibuild_entrypoint (no extra command or arguments are appended):

    * Executing build run commands: `cibuild -r check|build|test|deploy` dependant on CIBUILD_RUN env
    * Dynamic loading of external cibuild libs (CIBUILDER_BIN_URL and CIBUILDER_BIN_REF env vars). This will override the embedded cibuild libs. It is useful for debugging and development. This can be switched of in production mode on custom gitlab-runner by mounting an empty volume /tmp/cibuilder.locked
 
## Notes
-------------------
* For historical reasons, the image is based on docker:cli and includes requirements for all runs. In the future, it might also be useful to offer more specific and smaller images for Docker and Kubernetes environments and / or individual stages.

* The image builds and updates itself in a scheduled cibuild pipeline every week with disabled cache (use_cache=0). I accept the trade-offs of tying updates of the embedded components to the version cycle of the base docker:cli image.