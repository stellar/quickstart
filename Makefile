__PHONY__: build build-testing build-dev build-dev-deps

CORE_REPO_BRANCH=master
SOROBAN_TOOLS_REPO_BRANCH=main
GO_REPO_BRANCH := $(shell ./scripts/soroban_repo_to_horizon_repo.sh $(SOROBAN_TOOLS_REPO_BRANCH))

build:
	docker build --platform linux/amd64 -t stellar/quickstart -f Dockerfile .

build-testing:
	docker build --platform linux/amd64 -t stellar/quickstart:testing -f Dockerfile.testing .

build-soroban-dev:
	docker build --no-cache -t stellar/quickstart:soroban-dev -f Dockerfile.soroban-dev .

build-dev-deps-core:
	docker build -t stellar-core:dev -f docker/Dockerfile.testing https://github.com/stellar/stellar-core.git#$(CORE_REPO_BRANCH) --build-arg BUILDKIT_CONTEXT_KEEP_GIT_DIR=true --build-arg CFLAGS='' --build-arg CXXFLAGS='-stdlib=libc++' --build-arg CONFIGURE_FLAGS='--disable-tests'

build-dev-deps-horizon:
	docker build -t stellar-horizon:dev -f services/horizon/docker/Dockerfile.dev --target builder https://github.com/stellar/go.git#$(GO_REPO_BRANCH)

build-dev-deps-friendbot:
	docker build -t stellar-friendbot:dev -f services/friendbot/docker/Dockerfile https://github.com/stellar/go.git#$(GO_REPO_BRANCH)

build-dev-deps-soroban-rpc:
	docker build -t stellar-soroban-rpc:dev -f cmd/soroban-rpc/docker/Dockerfile --target build https://github.com/stellar/soroban-tools.git#$(SOROBAN_TOOLS_REPO_BRANCH)

# the build-dev-deps have the four dependencies for the building of the
# dockers for core, horizon, friendbot and soroban-rpc. Specifying these as dependencies
# allow the make to run these in parallel when sufficient paralalism is specified using the -j option.
build-dev-deps: build-dev-deps-core build-dev-deps-horizon build-dev-deps-friendbot build-dev-deps-soroban-rpc

build-dev: build-dev-deps
	docker build -t stellar/quickstart:dev -f Dockerfile.dev . --build-arg STELLAR_CORE_IMAGE_REF=stellar-core:dev --build-arg HORIZON_IMAGE_REF=stellar-horizon:dev --build-arg FRIENDBOT_IMAGE_REF=stellar-friendbot:dev --build-arg SOROBAN_RPC_IMAGE_REF=stellar-soroban-rpc:dev
