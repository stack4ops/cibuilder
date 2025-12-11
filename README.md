# cibuilder
-------------------
An image based on docker:cli for building container images in a gitlab pipeline with embedded cibuild libs (https://gitlab.com/stack4ops/public/cibuild).

## Image Customzing
-------------------
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
-------------------
* For historical reasons, the image is based on docker:cli and includes requirements for all stages. In the future, it might also be useful to offer more specific and smaller images for Docker and Kubernetes environments and / or individual stages.

* The image builds and updates itself in a scheduled cibuild pipeline every week:

    ```

                         ┌────────────────────────────┐
                         │  Check latest minor tag    │
                         │  for docker:cli base image │
                         └──────────────┬─────────────┘
                                        │
                       ┌────────────────┴────────────────┐
                       │                                 │
          ┌────────────▼────────────┐         ┌──────────▼─────────┐
          │ Newer minor tag exists? │    NO   │ No newer tag found │
          └────────────┬────────────┘         └──────────┬─────────┘
                       │                                 │
                       │ YES                             │
                       │                                 │
        ┌──────────────▼─────────────┐          ┌────────▼─────────┐
        │ Trigger build pipeline     │          │ Cancel pipeline  │
        │ (build → test → deploy)    │──────────│ gracefully (not  │
        └──────────────┬─────────────┘          │ marked as failed)│
                       │                        └────────┬─────────┘
                       │                                 │
        ┌──────────────▼─────────────┐         ┌─────────▼──────────┐
        │ Build pipeline succeeded?  │─────────│  Send notification │
        └──────────────┬─────────────┘   YES   │  (success/failure) │
                       │                       └──────────┬─────────┘
                       │ NO                               │
                       │                                  │
        ┌──────────────▼─────────────┐                    │
        │ Send failure notification  │<───────────────────┘
        └──────────────┬─────────────┘
                       │
                       │
        ┌──────────────▼───────────────────────────────────────────┐
        │ After successful pipeline:                               │
        │  Manual step required:                                   │
        │  Update group variable CI_DOCKER_REF with new minor tag  |
        |                                                          |  
        |  This is required because the referenced service         |           
        |  docker:dind image should also be based on the           |
        |  same docker version.                                    |
        │                                                          |
        └──────────────────────────────────────────────────────────┘
```    
