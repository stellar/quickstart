__PHONY__: run logs console build build-with-cache build-deps build-deps-xdr build-deps-core build-deps-horizon build-deps-friendbot build-deps-rpc build-deps-lab test fetch-cache

REVISION=$(shell git -c core.abbrev=no describe --always --exclude='*' --long --dirty)
TAG?=latest

# Cache settings for fetch-cache target
CACHE_ID?=
CACHE_PREFIX?=quickstart-
CACHE_REPO?=stellar/quickstart

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

# Build using pre-fetched cached images.
# Run 'make fetch-cache TAG=...' first to download the dependency images.
# This is much faster than 'make build' as it skips compiling dependencies.
build-with-cache: $(IMAGE_JSON)
	docker build -t stellar/quickstart:$(TAG) -f Dockerfile . \
		--build-arg REVISION=$(REVISION) \
		--build-arg XDR_IMAGE=stellar-xdr:$(XDR_SHA)-$(ARCH) \
		--build-arg CORE_IMAGE=stellar-core:$(CORE_SHA)-$(ARCH) \
		--build-arg RPC_IMAGE=stellar-rpc:$(RPC_SHA)-$(ARCH) \
		--build-arg GALEXIE_IMAGE=stellar-galexie:$(GALEXIE_SHA)-$(ARCH) \
		--build-arg HORIZON_IMAGE=stellar-horizon:$(HORIZON_SHA)-$(ARCH) \
		--build-arg FRIENDBOT_IMAGE=stellar-friendbot:$(FRIENDBOT_SHA)-$(ARCH) \
		--build-arg LAB_IMAGE=stellar-lab:$(LAB_SHA)-$(ARCH)

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

# Fetch pre-built dependency images from GitHub Actions cache or artifacts.
# This downloads cached Docker images from the stellar/quickstart repository's
# CI workflow, allowing faster local builds by skipping dependency compilation.
#
# Primary source: GitHub Actions cache (only accessible in GitHub Actions)
# Fallback source: Artifacts from latest completed CI workflow on main branch
#
# Usage:
#   make fetch-cache                    # Fetch deps for TAG=latest
#   make fetch-cache TAG=testing        # Fetch deps for a specific tag
#   make fetch-cache CACHE_ID=19        # Use a specific cache ID
#   make fetch-cache CACHE_REPO=myorg/quickstart  # Use a different repo
#
# After fetching, run: make build-with-cache TAG=...
fetch-cache: $(IMAGE_JSON)
	.scripts/fetch-cache \
		--tag "$(TAG)" \
		--image-json "$(IMAGE_JSON)" \
		--cache-id "$(CACHE_ID)" \
		--cache-prefix "$(CACHE_PREFIX)" \
		--repo "$(CACHE_REPO)" \
		--arch "$(ARCH)"
