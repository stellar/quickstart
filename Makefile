__PHONY__: run logs console build build-deps build-deps-xdr build-deps-core build-deps-horizon build-deps-friendbot build-deps-rpc build-deps-lab

REVISION=$(shell git -c core.abbrev=no describe --always --exclude='*' --long --dirty)
TAG?=latest

# Process images.json through the images-with-extras script
IMAGE_JSON=.image.json
.image.json: images.json .scripts/images-with-extras
	< images.json .scripts/images-with-extras | jq '.[] | select(.tag == "$(TAG)")' > $@

# Extract configuration from selected image
PROTOCOL_VERSION_DEFAULT = $(shell < $(IMAGE_JSON) jq -r '.config.protocol_version_default')
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
	$(MAKE) build-deps
	docker build -t stellar/quickstart:$(TAG) -f Dockerfile . \
	  --build-arg REVISION=$(REVISION) \
	  --build-arg PROTOCOL_VERSION_DEFAULT=$(PROTOCOL_VERSION_DEFAULT) \
	  --build-arg XDR_IMAGE_REF=stellar-xdr:$(XDR_SHA) \
	  --build-arg CORE_IMAGE_REF=stellar-core:$(CORE_SHA) \
	  --build-arg RPC_IMAGE_REF=stellar-rpc:$(RPC_SHA) \
	  --build-arg HORIZON_IMAGE_REF=stellar-horizon:$(HORIZON_SHA) \
	  --build-arg FRIENDBOT_IMAGE_REF=stellar-friendbot:$(FRIENDBOT_SHA) \
	  --build-arg LAB_IMAGE_REF=stellar-lab:$(LAB_SHA)

build-deps: build-deps-xdr build-deps-rpc build-deps-horizon build-deps-friendbot build-deps-lab build-deps-core

build-deps-xdr: $(IMAGE_JSON)
	docker build -t stellar-xdr:$(XDR_SHA) -f Dockerfile.xdr . --build-arg REPO="$(XDR_REPO)" --build-arg REF="$(XDR_SHA)"

build-deps-core: $(IMAGE_JSON)
	docker build -t stellar-core:$(CORE_SHA) -f Dockerfile.core . --build-arg REPO="$(CORE_REPO)" --build-arg REF="$(CORE_SHA)" --build-arg OPTIONS='$(CORE_OPTIONS)'

build-deps-rpc: $(IMAGE_JSON)
	docker build -t stellar-rpc:$(RPC_SHA) -f Dockerfile.rpc . --build-arg=REPO="$(RPC_REPO)" --build-arg REF="$(RPC_SHA)"

build-deps-horizon: $(IMAGE_JSON)
	docker build -t stellar-horizon:$(HORIZON_SHA) -f Dockerfile.horizon . --build-arg REPO="$(HORIZON_REPO)" --build-arg REF="$(HORIZON_SHA)"

build-deps-friendbot: $(IMAGE_JSON)
	docker build -t stellar-friendbot:$(FRIENDBOT_SHA) -f Dockerfile.friendbot . --build-arg REPO="$(FRIENDBOT_REPO)" --build-arg REF="$(FRIENDBOT_SHA)"

build-deps-lab: $(IMAGE_JSON)
	docker build -t stellar-lab:$(LAB_SHA) -f Dockerfile.lab . --build-arg REPO="$(LAB_REPO)" --build-arg NEXT_PUBLIC_COMMIT_HASH=$(LAB_SHA)
