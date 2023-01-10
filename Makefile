__PHONY__: build build-dev-deps

CORE_REPO_BRANCH=master
SOROBAN_TOOLS_REPO_BRANCH=main
GO_REPO_BRANCH := $(shell ./scripts/soroban_repo_to_horizon_repo.sh $(SOROBAN_TOOLS_REPO_BRANCH))

build-soroban-dev:
	docker build --no-cache -t stellar/quickstart:soroban-dev -f Dockerfile.soroban-dev .

build-deps-core:
	docker build -t stellar-core:dev -f docker/Dockerfile.testing https://github.com/stellar/stellar-core.git#$(CORE_REPO_BRANCH) --build-arg BUILDKIT_CONTEXT_KEEP_GIT_DIR=true --build-arg CONFIGURE_FLAGS='--disable-tests'

build-deps-horizon:
	docker build -t stellar-horizon:dev -f services/horizon/docker/Dockerfile.dev --target builder https://github.com/stellar/go.git#$(GO_REPO_BRANCH)

build-deps-friendbot:
	docker build -t stellar-friendbot:dev -f services/friendbot/docker/Dockerfile https://github.com/stellar/go.git#$(GO_REPO_BRANCH)

build-deps-soroban-rpc:
	docker build -t stellar-soroban-rpc:dev -f cmd/soroban-rpc/docker/Dockerfile --target build https://github.com/stellar/soroban-tools.git#$(SOROBAN_TOOLS_REPO_BRANCH)

# the build-deps have the four dependencies for the building of the
# dockers for core, horizon, friendbot and soroban-rpc. Specifying these as dependencies
# allow the make to run these in parallel when sufficient paralalism is specified using the -j option.
build-deps: build-deps-core build-deps-horizon build-deps-friendbot build-deps-soroban-rpc

build: build-deps
	docker build -t stellar/quickstart:dev -f Dockerfile . --build-arg STELLAR_CORE_IMAGE_REF=stellar-core:dev --build-arg HORIZON_IMAGE_REF=stellar-horizon:dev --build-arg FRIENDBOT_IMAGE_REF=stellar-friendbot:dev --build-arg SOROBAN_RPC_IMAGE_REF=stellar-soroban-rpc:dev
