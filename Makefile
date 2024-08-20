__PHONY__: run logs build build-deps build-deps-core build-deps-horizon build-deps-friendbot build-deps-soroban-rpc

REVISION=$(shell git -c core.abbrev=no describe --always --exclude='*' --long --dirty)
TAG?=dev
PROTOCOL_VERSION_DEFAULT?=
XDR_REPO?=https://github.com/stellar/rs-stellar-xdr.git
XDR_REF?=main
CORE_REPO?=https://github.com/stellar/stellar-core.git
CORE_REF?=master
CORE_CONFIGURE_FLAGS?=--disable-tests
SOROBAN_RPC_REF?=main
HORIZON_REF?=$(shell ./scripts/soroban_repo_to_horizon_repo.sh $(SOROBAN_RPC_REF))
FRIENDBOT_REF?=$(HORIZON_REF)

run:
	docker run --rm --name stellar -p 8000:8000 stellar/quickstart:$(TAG) --local --enable-soroban-rpc

logs:
	docker exec stellar /bin/sh -c 'tail -F /var/log/supervisor/*'

console:
	docker exec -it stellar /bin/bash

build-latest:
	$(MAKE) build TAG=latest \
		PROTOCOL_VERSION_DEFAULT=20 \
		XDR_REF=v21.1.0 \
		CORE_REF=v21.3.0 \
		HORIZON_REF=horizon-v2.32.0 \
		SOROBAN_RPC_REF=v21.2.0 \
		FRIENDBOT_REF=31fc8f4236388f12fc609228b7a7f5494867a1f9

build-testing:
	$(MAKE) build TAG=testing \
	    PROTOCOL_VERSION_DEFAULT=21 \
		XDR_REF=v21.1.0 \
		CORE_REF=v21.3.0 \
		HORIZON_REF=horizon-v2.32.0 \
		SOROBAN_RPC_REF=v21.2.0 \
		FRIENDBOT_REF=31fc8f4236388f12fc609228b7a7f5494867a1f9

build-future:
	$(MAKE) build TAG=future \
		PROTOCOL_VERSION_DEFAULT=21 \
		XDR_REF=v21.1.0 \
		CORE_REF=v21.3.0 \
		HORIZON_REF=horizon-v2.32.0 \
		SOROBAN_RPC_REF=v21.2.0 \
		FRIENDBOT_REF=31fc8f4236388f12fc609228b7a7f5494867a1f9

build:
	$(MAKE) -j 4 build-deps
	docker build -t stellar/quickstart:$(TAG) -f Dockerfile . \
	  --build-arg REVISION=$(REVISION) \
	  --build-arg PROTOCOL_VERSION_DEFAULT=$(PROTOCOL_VERSION_DEFAULT) \
	  --build-arg STELLAR_XDR_IMAGE_REF=stellar-xdr:$(XDR_REF) \
	  --build-arg STELLAR_CORE_IMAGE_REF=stellar-core:$(CORE_REF) \
	  --build-arg HORIZON_IMAGE_REF=stellar-horizon:$(HORIZON_REF) \
	  --build-arg FRIENDBOT_IMAGE_REF=stellar-friendbot:$(FRIENDBOT_REF) \
	  --build-arg SOROBAN_RPC_IMAGE_REF=stellar-soroban-rpc:$(SOROBAN_RPC_REF) \

build-deps: build-deps-xdr build-deps-core build-deps-horizon build-deps-friendbot build-deps-soroban-rpc

build-deps-xdr:
	docker build -t stellar-xdr:$(XDR_REF) -f Dockerfile.xdr --target builder . --build-arg REPO="$(XDR_REPO)" --build-arg REF="$(XDR_REF)"

build-deps-core:
	docker build -t stellar-core:$(CORE_REF) -f docker/Dockerfile.testing $(CORE_REPO)#$(CORE_REF) --build-arg BUILDKIT_CONTEXT_KEEP_GIT_DIR=true --build-arg CONFIGURE_FLAGS="$(CORE_CONFIGURE_FLAGS)"

build-deps-horizon:
	docker build -t stellar-horizon:$(HORIZON_REF) -f Dockerfile.horizon --target builder . --build-arg REF="$(HORIZON_REF)"

build-deps-friendbot:
	docker build -t stellar-friendbot:$(FRIENDBOT_REF) -f services/friendbot/docker/Dockerfile https://github.com/stellar/go.git#$(FRIENDBOT_REF)

build-deps-soroban-rpc:
	docker build -t stellar-soroban-rpc:$(SOROBAN_RPC_REF) -f cmd/soroban-rpc/docker/Dockerfile --target build https://github.com/stellar/soroban-rpc.git#$(SOROBAN_RPC_REF) --build-arg BUILDKIT_CONTEXT_KEEP_GIT_DIR=true
