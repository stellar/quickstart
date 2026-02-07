__PHONY__: run logs console build build-deps build-deps-xdr build-deps-core build-deps-horizon build-deps-friendbot build-deps-rpc build-deps-lab test fetch-cache

REVISION=$(shell git -c core.abbrev=no describe --always --exclude='*' --long --dirty)
TAG?=latest

# Detect native architecture for Docker images
UNAME_M := $(shell uname -m)
ifeq ($(UNAME_M),x86_64)
    ARCH := amd64
else ifeq ($(UNAME_M),amd64)
    ARCH := amd64
else ifeq ($(UNAME_M),arm64)
    ARCH := arm64
else ifeq ($(UNAME_M),aarch64)
    ARCH := arm64
else
    ARCH := amd64
endif

# Process images.json through the images-with-extras script
IMAGE_JSON=.image.json
.image.json: images.json .scripts/images-with-extras
	< images.json jq '.[] | select(.tag == "$(TAG)") | [ . ]' | .scripts/images-with-extras | jq '.[]' > $@

# Extract configuration from selected image
XDR_REPO =          $(shell < $(IMAGE_JSON) jq -r '.deps[] | select(.name == "xdr") | .repo')
XDR_SHA =           $(shell < $(IMAGE_JSON) jq -r '.deps[] | select(.name == "xdr") | .sha')
CORE_REPO =         $(shell < $(IMAGE_JSON) jq -r '.deps[] | select(.name == "core") | .repo')
CORE_SHA =          $(shell < $(IMAGE_JSON) jq -r '.deps[] | select(.name == "core") | .sha')
CORE_OPTIONS =      $(shell < $(IMAGE_JSON) jq -c '.deps[] | select(.name == "core") | .options // {}')
RPC_REPO =          $(shell < $(IMAGE_JSON) jq -r '.deps[] | select(.name == "rpc") | .repo')
RPC_SHA =           $(shell < $(IMAGE_JSON) jq -r '.deps[] | select(.name == "rpc") | .sha')
GALEXIE_REPO =      $(shell < $(IMAGE_JSON) jq -r '.deps[] | select(.name == "galexie") | .repo')
GALEXIE_SHA =       $(shell < $(IMAGE_JSON) jq -r '.deps[] | select(.name == "galexie") | .sha')
HORIZON_REPO =      $(shell < $(IMAGE_JSON) jq -r '.deps[] | select(.name == "horizon") | .repo')
HORIZON_SHA =       $(shell < $(IMAGE_JSON) jq -r '.deps[] | select(.name == "horizon") | .sha')
HORIZON_OPTIONS =   $(shell < $(IMAGE_JSON) jq -c '.deps[] | select(.name == "horizon") | .options // {}')
FRIENDBOT_REPO =    $(shell < $(IMAGE_JSON) jq -r '.deps[] | select(.name == "friendbot") | .repo')
FRIENDBOT_SHA =     $(shell < $(IMAGE_JSON) jq -r '.deps[] | select(.name == "friendbot") | .sha')
FRIENDBOT_OPTIONS = $(shell < $(IMAGE_JSON) jq -c '.deps[] | select(.name == "friendbot") | .options // {}')
LAB_REPO =          $(shell < $(IMAGE_JSON) jq -r '.deps[] | select(.name == "lab") | .repo')
LAB_SHA =           $(shell < $(IMAGE_JSON) jq -r '.deps[] | select(.name == "lab") | .sha')

run:
	docker run --rm -i --name stellar -p 8000:8000 -p 11626:11626 stellar/quickstart:$(TAG) --local

logs:
	docker exec stellar /bin/sh -c 'tail -F /var/log/supervisor/*'

console:
	docker exec -it stellar /bin/bash

# Build using pre-fetched cached images if available.
# Run 'make fetch-cache TAG=...' first to download the dependency images.
# If cached images exist, Docker will use them automatically.
# Otherwise, dependencies will be built from source.
build: $(IMAGE_JSON)
	docker build -t stellar/quickstart:$(TAG) -f Dockerfile . \
		--build-arg REVISION=$(REVISION) \
		--build-arg XDR_REPO=$(XDR_REPO) --build-arg XDR_REF=$(XDR_SHA) \
		--build-arg CORE_REPO="$(CORE_REPO)" --build-arg CORE_REF="$(CORE_SHA)" --build-arg CORE_OPTIONS='$(CORE_OPTIONS)' \
		--build-arg RPC_REPO="$(RPC_REPO)" --build-arg RPC_REF="$(RPC_SHA)" \
		--build-arg GALEXIE_REPO="$(GALEXIE_REPO)" --build-arg GALEXIE_REF="$(GALEXIE_SHA)" \
		--build-arg HORIZON_REPO="$(HORIZON_REPO)" --build-arg HORIZON_REF="$(HORIZON_SHA)" --build-arg HORIZON_OPTIONS='$(HORIZON_OPTIONS)' \
		--build-arg FRIENDBOT_REPO="$(FRIENDBOT_REPO)" --build-arg FRIENDBOT_REF="$(FRIENDBOT_SHA)" --build-arg FRIENDBOT_OPTIONS='$(FRIENDBOT_OPTIONS)' \
		--build-arg LAB_REPO="$(LAB_REPO)" --build-arg LAB_REF=$(LAB_SHA)

# Run the same tests that CI runs against a running quickstart container.
# Build and run the container first with: make build run TAG=...
# These mirror the tests run in the CI workflow (.github/workflows/internal-test.yml)
test:
	go run tests/test_core.go
	go run tests/test_horizon_up.go
	go run tests/test_horizon_core_up.go
	go run tests/test_horizon_ingesting.go
	go run tests/test_friendbot.go
	go run tests/test_stellar_rpc_up.go
	go run tests/test_stellar_rpc_healthy.go

# Fetch pre-built dependency images from GitHub Actions artifacts.
# This downloads cached Docker images from the stellar/quickstart repository's
# CI workflow, allowing faster local builds by skipping dependency compilation.
#
# The images are tagged with the stage names expected by the Dockerfile, so
# running 'make build' after this will automatically use the cached images.
#
# Usage:
#   make fetch-cache                    # Fetch deps for TAG=latest
#   make fetch-cache TAG=testing        # Fetch deps for a specific tag
#   make fetch-cache TAG=nightly        # Fetch nightly build deps
#
# After fetching, run: make build TAG=...
fetch-cache: $(IMAGE_JSON)
	.scripts/fetch-cache \
		--tag "$(TAG)" \
		--image-json "$(IMAGE_JSON)" \
		--arch "$(ARCH)"
