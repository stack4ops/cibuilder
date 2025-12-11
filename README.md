# cibuilder

An image based on docker:cli for building container images in a gitlab pipeline with embedded cibuild libs (https://gitlab.com/stack4ops/public/cibuild).

## Image Customzing

* Running as non-root

* Pipeline stage requirements:
    * **check**: skopeo and jq
    * **build**: buildctl for direct communication with buildkitd endpoints over mTLS
    * **test**: kubectl for testing images in kubernetes environments
    * **deploy**: skopeo for image copy (re-tagging)

* Embedded cibuild libs: https://gitlab.com/stack4ops/public/cibuild

* Custom cibuild_entrypoint:

    * Executing build stages as run commands: `cibuild -s check|build|test|deploy`
    * Dynamic loading of external cibuild libs (CIBUILDER_BIN_URL and CIBUILDER_BIN_REF env vars). This will override the embedded cibuild libs. It is useful for debugging and development.
 
## Notes

* For historical reasons, the image is based on docker:cli and includes requirements for all stages. In the future, it might also be useful to offer more specific and smaller images for Docker and Kubernetes environments and / or individual stages.

* The image builds and updates itself in a scheduled cibuild pipeline every week:

    * checks if newer minortag for docker:cli base image exists.

    * If newer base image exists: trigger build, test and deploy stages otherwise cancel pipeline gracefully but NOT as failed pipeline because we don't want notifications for every cancellation event.

    * If build pipeline succeeded or failed, send a notification to registered recipients

    * After succeeded pipeline, there is only one manual action required for this specific build image that is referenced in all .gitlab-ci.yaml files of image build repos in this group: Setting the group variable `CI_DOCKER_REF` to the new minortag. This is required because the referenced service docker:dind image should also be based on the same docker version.
