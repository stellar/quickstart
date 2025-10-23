__PHONY__: run logs console build build-deps build-deps-xdr build-deps-core build-deps-horizon build-deps-friendbot build-deps-rpc build-deps-lab

REVISION=$(shell git -c core.abbrev=no describe --always --exclude='*' --long --dirty)
TAG?=latest

# Process images.json through the images-with-extras script
IMAGE_JSON=.image.json
.image.json: images.json .scripts/images-with-extras
	< images.json .scripts/images-with-extras | jq '.[] | select(.tag == "$(TAG)")' > $@

# Extract configuration from selected image
XDR_REPO =       $(shell < $(IMAGE_JSON) jq -r '.deps[] | select(.name == "xdr") | .repo')
XDR_SHA =        $(shell < $(IMAGE_JSON) jq -r '.deps[] | select(.name == "xdr") | .sha')
CORE_REPO =      $(shell < $(IMAGE_JSON) jq -r '.deps[] | select(.name == "core") | .repo')
CORE_SHA =       $(shell < $(IMAGE_JSON) jq -r '.deps[] | select(.name == "core") | .sha')
CORE_OPTIONS =   $(shell < $(IMAGE_JSON) jq -c '.deps[] | select(.name == "core") | .options // {}')
RPC_REPO =       $(shell < $(IMAGE_JSON) jq -r '.deps[] | select(.name == "rpc") | .repo')
RPC_SHA =        $(shell < $(IMAGE_JSON) jq -r '.deps[] | select(.name == "rpc") | .sha')
HORIZON_REPO =   $(shell < $(IMAGE_JSON) jq -r '.deps[] | select(.name == "horizon") | .repo')
HORIZON_SHA =    $(shell < $(IMAGE_JSON) jq -r '.deps[] | select(.name == "horizon") | .sha')
FRIENDBOT_REPO = $(shell < $(IMAGE_JSON) jq -r '.deps[] | select(.name == "friendbot") | .repo')
FRIENDBOT_SHA =  $(shell < $(IMAGE_JSON) jq -r '.deps[] | select(.name == "friendbot") | .sha')
LAB_REPO =       $(shell < $(IMAGE_JSON) jq -r '.deps[] | select(.name == "lab") | .repo')
LAB_SHA =        $(shell < $(IMAGE_JSON) jq -r '.deps[] | select(.name == "lab") | .sha')

run:
	docker run --rm --name stellar -p 8000:8000 stellar/quickstart:$(TAG) --local

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
		--build-arg HORIZON_REPO="$(HORIZON_REPO)" --build-arg HORIZON_REF="$(HORIZON_SHA)" \
		--build-arg FRIENDBOT_REPO="$(FRIENDBOT_REPO)" --build-arg FRIENDBOT_REF="$(FRIENDBOT_SHA)" \
		--build-arg LAB_REPO="$(LAB_REPO)" --build-arg LAB_REF=$(LAB_SHA)
