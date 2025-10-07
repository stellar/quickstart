__PHONY__: run logs console build build-deps build-deps-xdr build-deps-core build-deps-horizon build-deps-friendbot build-deps-rpc build-deps-lab

REVISION=$(shell git -c core.abbrev=no describe --always --exclude='*' --long --dirty)
TAG?=latest

# Extract configuration from images.json
PROTOCOL_VERSION_DEFAULT = $(shell jq -r '.[] | select(.tag == "$(TAG)") | .config.protocol_version_default' images.json)
XDR_REPO = $(shell jq -r '.[] | select(.tag == "$(TAG)") | .deps[] | select(.name == "xdr") | .repo' images.json)
XDR_REF = $(shell jq -r '.[] | select(.tag == "$(TAG)") | .deps[] | select(.name == "xdr") | .ref' images.json)
CORE_REPO = $(shell jq -r '.[] | select(.tag == "$(TAG)") | .deps[] | select(.name == "core") | .repo' images.json)
CORE_REF = $(shell jq -r '.[] | select(.tag == "$(TAG)") | .deps[] | select(.name == "core") | .ref' images.json)
CORE_OPTIONS = $(shell jq -c '.[] | select(.tag == "$(TAG)") | .deps[] | select(.name == "core") | .options // {}' images.json)
RPC_REPO = $(shell jq -r '.[] | select(.tag == "$(TAG)") | .deps[] | select(.name == "rpc") | .repo' images.json)
RPC_REF = $(shell jq -r '.[] | select(.tag == "$(TAG)") | .deps[] | select(.name == "rpc") | .ref' images.json)
HORIZON_REPO = $(shell jq -r '.[] | select(.tag == "$(TAG)") | .deps[] | select(.name == "horizon") | .repo' images.json)
HORIZON_REF = $(shell jq -r '.[] | select(.tag == "$(TAG)") | .deps[] | select(.name == "horizon") | .ref' images.json)
FRIENDBOT_REPO = $(shell jq -r '.[] | select(.tag == "$(TAG)") | .deps[] | select(.name == "friendbot") | .repo' images.json)
FRIENDBOT_REF = $(shell jq -r '.[] | select(.tag == "$(TAG)") | .deps[] | select(.name == "friendbot") | .ref' images.json)
LAB_REPO = $(shell jq -r '.[] | select(.tag == "$(TAG)") | .deps[] | select(.name == "lab") | .repo' images.json)
LAB_REF = $(shell jq -r '.[] | select(.tag == "$(TAG)") | .deps[] | select(.name == "lab") | .ref' images.json)

run:
	docker run --rm --name stellar -p 8000:8000 stellar/quickstart:$(TAG) --local

logs:
	docker exec stellar /bin/sh -c 'tail -F /var/log/supervisor/*'

console:
	docker exec -it stellar /bin/bash

build:
	< images.json jq -c --arg tag '$(TAG)' '.[] | select(.tag == $$tag)' > image.json
	$(MAKE) build-deps
	docker build -t stellar/quickstart:$(TAG) -f Dockerfile . \
	  --build-arg REVISION=$(REVISION) \
	  --build-arg PROTOCOL_VERSION_DEFAULT=$(PROTOCOL_VERSION_DEFAULT) \
	  --build-arg XDR_IMAGE_REF=stellar-xdr:$(XDR_REF) \
	  --build-arg CORE_IMAGE_REF=stellar-core:$(CORE_REF) \
	  --build-arg RPC_IMAGE_REF=stellar-rpc:$(RPC_REF) \
	  --build-arg HORIZON_IMAGE_REF=stellar-horizon:$(HORIZON_REF) \
	  --build-arg FRIENDBOT_IMAGE_REF=stellar-friendbot:$(FRIENDBOT_REF) \
	  --build-arg LAB_IMAGE_REF=stellar-lab:$(LAB_REF)

build-deps: build-deps-xdr build-deps-rpc build-deps-horizon build-deps-friendbot build-deps-lab build-deps-core

build-deps-xdr:
	docker build -t stellar-xdr:$(XDR_REF) -f Dockerfile.xdr . --build-arg REPO="$(XDR_REPO)" --build-arg REF="$(XDR_REF)"

build-deps-core:
	docker build -t stellar-core:$(CORE_REF) -f Dockerfile.core . --build-arg REPO="$(CORE_REPO)" --build-arg REF="$(CORE_REF)" --build-arg OPTIONS='$(CORE_OPTIONS)'

build-deps-rpc:
	docker build -t stellar-rpc:$(RPC_REF) -f Dockerfile.rpc . --build-arg=REPO="$(RPC_REPO)" --build-arg REF="$(RPC_REF)"

build-deps-horizon:
	docker build -t stellar-horizon:$(HORIZON_REF) -f Dockerfile.horizon . --build-arg REPO="$(HORIZON_REPO)" --build-arg REF="$(HORIZON_REF)"

build-deps-friendbot:
	docker build -t stellar-friendbot:$(FRIENDBOT_REF) -f Dockerfile.friendbot . --build-arg REPO="$(FRIENDBOT_REPO)" --build-arg REF="$(FRIENDBOT_REF)"

build-deps-lab:
	docker build -t stellar-lab:$(LAB_REF) -f Dockerfile.lab . --build-arg REPO="$(LAB_REPO)" --build-arg NEXT_PUBLIC_COMMIT_HASH=$(LAB_REF)
