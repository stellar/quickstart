__PHONY__: run logs build build-deps build-deps-core build-deps-horizon build-deps-friendbot build-deps-stellar-rpc

REVISION=$(shell git -c core.abbrev=no describe --always --exclude='*' --long --dirty)
TAG?=dev
PROTOCOL_VERSION_DEFAULT?=22
XDR_REPO?=https://github.com/stellar/rs-stellar-xdr.git
XDR_REF?=main
CORE_REPO?=https://github.com/stellar/stellar-core.git
CORE_REF?=master
CORE_CONFIGURE_FLAGS?=--disable-tests
STELLAR_RPC_REF?=main
HORIZON_REF?=master
FRIENDBOT_REF?=$(HORIZON_REF)
LAB_REF?=main

run:
	docker run --rm --name stellar -p 8000:8000 stellar/quickstart:$(TAG) --local --enable-stellar-rpc

logs:
	docker exec stellar /bin/sh -c 'tail -F /var/log/supervisor/*'

console:
	docker exec -it stellar /bin/bash

build-latest:
	$(MAKE) build TAG=latest \
		PROTOCOL_VERSION_DEFAULT=$(shell jq -r '.latest.protocol_version_default' images.json) \
		XDR_REF=$(shell jq -r '.latest.xdr_ref' images.json) \
		CORE_REF=$(shell jq -r '.latest.core_ref' images.json) \
		HORIZON_REF=$(shell jq -r '.latest.horizon_ref' images.json) \
		STELLAR_RPC_REF=$(shell jq -r '.latest.stellar_rpc_ref' images.json) \
		FRIENDBOT_REF=$(shell jq -r '.latest.friendbot_ref' images.json) \
		LAB_REF=$(shell jq -r '.latest.lab_ref' images.json)

build-testing:
	$(MAKE) build TAG=testing \
		PROTOCOL_VERSION_DEFAULT=$(shell jq -r '.testing.protocol_version_default' images.json) \
		XDR_REF=$(shell jq -r '.testing.xdr_ref' images.json) \
		CORE_REF=$(shell jq -r '.testing.core_ref' images.json) \
		HORIZON_REF=$(shell jq -r '.testing.horizon_ref' images.json) \
		STELLAR_RPC_REF=$(shell jq -r '.testing.stellar_rpc_ref' images.json) \
		FRIENDBOT_REF=$(shell jq -r '.testing.friendbot_ref' images.json) \
		LAB_REF=$(shell jq -r '.testing.lab_ref' images.json)

build-future:
	$(MAKE) build TAG=future \
		PROTOCOL_VERSION_DEFAULT=$(shell jq -r '.future.protocol_version_default' images.json) \
		XDR_REF=$(shell jq -r '.future.xdr_ref' images.json) \
		CORE_REF=$(shell jq -r '.future.core_ref' images.json) \
		HORIZON_REF=$(shell jq -r '.future.horizon_ref' images.json) \
		STELLAR_RPC_REF=$(shell jq -r '.future.stellar_rpc_ref' images.json) \
		FRIENDBOT_REF=$(shell jq -r '.future.friendbot_ref' images.json) \
		LAB_REF=$(shell jq -r '.future.lab_ref' images.json)

build:
	$(MAKE) -j 4 build-deps
	docker build -t stellar/quickstart:$(TAG) -f Dockerfile . \
	  --build-arg REVISION=$(REVISION) \
	  --build-arg PROTOCOL_VERSION_DEFAULT=$(PROTOCOL_VERSION_DEFAULT) \
	  --build-arg STELLAR_XDR_IMAGE_REF=stellar-xdr:$(XDR_REF) \
	  --build-arg STELLAR_CORE_IMAGE_REF=stellar-core:$(CORE_REF) \
	  --build-arg HORIZON_IMAGE_REF=stellar-horizon:$(HORIZON_REF) \
	  --build-arg FRIENDBOT_IMAGE_REF=stellar-friendbot:$(FRIENDBOT_REF) \
	  --build-arg STELLAR_RPC_IMAGE_REF=stellar-rpc:$(STELLAR_RPC_REF) \
	  --build-arg LAB_IMAGE_REF=stellar-lab:$(LAB_REF)

build-deps: build-deps-xdr build-deps-core build-deps-horizon build-deps-friendbot build-deps-stellar-rpc build-deps-lab

build-deps-xdr:
	docker build -t stellar-xdr:$(XDR_REF) -f Dockerfile.xdr . --build-arg REPO="$(XDR_REPO)" --build-arg REF="$(XDR_REF)"

build-deps-core:
	docker build -t stellar-core:$(CORE_REF) -f docker/Dockerfile.testing $(CORE_REPO)#$(CORE_REF) --build-arg BUILDKIT_CONTEXT_KEEP_GIT_DIR=true --build-arg CONFIGURE_FLAGS="$(CORE_CONFIGURE_FLAGS)"

build-deps-horizon:
	docker build -t stellar-horizon:$(HORIZON_REF) -f Dockerfile.horizon . --build-arg REF="$(HORIZON_REF)"

build-deps-friendbot:
	docker build -t stellar-friendbot:$(FRIENDBOT_REF) -f services/friendbot/docker/Dockerfile https://github.com/stellar/go.git#$(FRIENDBOT_REF)

build-deps-stellar-rpc:
	docker build -t stellar-rpc:$(STELLAR_RPC_REF) -f cmd/stellar-rpc/docker/Dockerfile --target build https://github.com/stellar/stellar-rpc.git#$(STELLAR_RPC_REF) --build-arg BUILDKIT_CONTEXT_KEEP_GIT_DIR=true

build-deps-lab:
	docker build -t stellar-lab:$(LAB_REF) -f Dockerfile.lab . --build-arg NEXT_PUBLIC_COMMIT_HASH=$(LAB_REF)
