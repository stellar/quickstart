__PHONY__: run logs build build-deps build-deps-core build-deps-horizon build-deps-friendbot build-deps-soroban-rpc

TAG?=dev
CORE_REPO?=https://github.com/stellar/stellar-core.git
CORE_REF?=master
CORE_CONFIGURE_FLAGS?=--disable-tests
CORE_SUPPORTS_TESTING_SOROBAN_HIGH_LIMIT_OVERRIDE?=false
CORE_SUPPORTS_ENABLE_SOROBAN_DIAGNOSTIC_EVENTS?=false
SOROBAN_RPC_REF?=main
HORIZON_REF?=$(shell ./scripts/soroban_repo_to_horizon_repo.sh $(SOROBAN_RPC_REF))
FRIENDBOT_REF?=$(HORIZON_REF)

run:
	docker run --rm --name stellar -p 8000:8000 stellar/quickstart:$(TAG) --standalone --enable-soroban-rpc

logs:
	docker exec stellar /bin/sh -c 'tail -F /var/log/supervisor/*'

console:
	docker exec -it stellar /bin/bash

build-latest:
	$(MAKE) build TAG=latest \
		CORE_REF=v19.14.0 \
		HORIZON_REF=horizon-v2.26.1 \
		SOROBAN_RPC_REF=v0.4.0

build-testing:
	$(MAKE) build TAG=testing \
		CORE_REF=v20.0.0-rc.2.1 \
		CORE_SUPPORTS_TESTING_SOROBAN_HIGH_LIMIT_OVERRIDE=true \
		CORE_SUPPORTS_ENABLE_SOROBAN_DIAGNOSTIC_EVENTS=true \
		HORIZON_REF=horizon-v2.27.0-rc1 \
		SOROBAN_RPC_REF=v20.0.0-rc4

build-soroban-dev:
	$(MAKE) build TAG=soroban-dev \
		CORE_REPO=https://github.com/sisuresh/stellar-core.git \
		CORE_REF=cc71408d70172bafa5969fc0e0102af8ba60c3d3 \
		CORE_SUPPORTS_ENABLE_SOROBAN_DIAGNOSTIC_EVENTS=true \
		HORIZON_REF=horizon-v2.27.0-rc1 \
		SOROBAN_RPC_REF=v20.0.0-rc4

build:
	$(MAKE) -j 4 build-deps
	docker build -t stellar/quickstart:$(TAG) -f Dockerfile . --build-arg STELLAR_CORE_IMAGE_REF=stellar-core:$(CORE_REF) --build-arg HORIZON_IMAGE_REF=stellar-horizon:$(HORIZON_REF) --build-arg FRIENDBOT_IMAGE_REF=stellar-friendbot:$(FRIENDBOT_REF) --build-arg SOROBAN_RPC_IMAGE_REF=stellar-soroban-rpc:$(SOROBAN_RPC_REF) --build-arg CORE_SUPPORTS_TESTING_SOROBAN_HIGH_LIMIT_OVERRIDE=$(CORE_SUPPORTS_TESTING_SOROBAN_HIGH_LIMIT_OVERRIDE) --build-arg CORE_SUPPORTS_ENABLE_SOROBAN_DIAGNOSTIC_EVENTS=$(CORE_SUPPORTS_ENABLE_SOROBAN_DIAGNOSTIC_EVENTS)

build-deps: build-deps-core build-deps-horizon build-deps-friendbot build-deps-soroban-rpc

build-deps-core:
	docker build -t stellar-core:$(CORE_REF) -f docker/Dockerfile.testing $(CORE_REPO)#$(CORE_REF) --build-arg BUILDKIT_CONTEXT_KEEP_GIT_DIR=true --build-arg CONFIGURE_FLAGS="$(CORE_CONFIGURE_FLAGS)"

build-deps-horizon:
	docker build -t stellar-horizon:$(HORIZON_REF) -f Dockerfile.horizon --target builder . --build-arg REF="$(HORIZON_REF)"

build-deps-friendbot:
	docker build -t stellar-friendbot:$(FRIENDBOT_REF) -f services/friendbot/docker/Dockerfile https://github.com/stellar/go.git#$(FRIENDBOT_REF)

build-deps-soroban-rpc:
	docker build -t stellar-soroban-rpc:$(SOROBAN_RPC_REF) -f cmd/soroban-rpc/docker/Dockerfile --target build https://github.com/stellar/soroban-tools.git#$(SOROBAN_RPC_REF) --build-arg BUILDKIT_CONTEXT_KEEP_GIT_DIR=true
