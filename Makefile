__PHONY__: build build-deps

TAG?=dev
CORE_REF?=master
CORE_CONFIGURE_FLAGS?=--disable-tests
SOROBAN_TOOLS_REF?=main
GO_REF?=$(shell ./scripts/soroban_repo_to_horizon_repo.sh $(SOROBAN_TOOLS_REF))

build-deps-core:
	docker build -t stellar-core:$(TAG) -f docker/Dockerfile.testing https://github.com/stellar/stellar-core.git#$(CORE_REF) --build-arg BUILDKIT_CONTEXT_KEEP_GIT_DIR=true --build-arg CONFIGURE_FLAGS="$(CORE_CONFIGURE_FLAGS)"

build-deps-horizon:
	docker build -t stellar-horizon:$(TAG) -f Dockerfile.horizon --target builder . --build-arg REF="$(GO_REF)"

build-deps-friendbot:
	docker build -t stellar-friendbot:$(TAG) -f services/friendbot/docker/Dockerfile https://github.com/stellar/go.git#$(GO_REF)

build-deps-soroban-rpc:
	docker build -t stellar-soroban-rpc:$(TAG) -f cmd/soroban-rpc/docker/Dockerfile --target build https://github.com/stellar/soroban-tools.git#$(SOROBAN_TOOLS_REF)

# the build-deps have the four dependencies for the building of the
# dockers for core, horizon, friendbot and soroban-rpc. Specifying these as dependencies
# allow the make to run these in parallel when sufficient paralalism is specified using the -j option.
build-deps: build-deps-core build-deps-horizon build-deps-friendbot build-deps-soroban-rpc

build: build-deps
	docker build -t stellar/quickstart:$(TAG) -f Dockerfile . --build-arg STELLAR_CORE_IMAGE_REF=stellar-core:$(TAG) --build-arg HORIZON_IMAGE_REF=stellar-horizon:$(TAG) --build-arg FRIENDBOT_IMAGE_REF=stellar-friendbot:$(TAG) --build-arg SOROBAN_RPC_IMAGE_REF=stellar-soroban-rpc:$(TAG)
