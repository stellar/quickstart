__PHONY__: build build-testing build-dev build-dev-deps

GO_REPO_BRANCH=master	
CORE_REPO_BRANCH=master	

build:
	docker build --platform linux/amd64 -t stellar/quickstart -f Dockerfile .

build-testing:
	docker build --platform linux/amd64 -t stellar/quickstart:testing -f Dockerfile.testing .

build-soroban-dev:
	docker build --platform linux/amd64 --no-cache -t stellar/quickstart:soroban-dev -f Dockerfile.soroban-dev .

build-dev-deps:
	docker build --platform linux/amd64 -t stellar-core:dev -f docker/Dockerfile.testing https://github.com/stellar/stellar-core.git#$(CORE_REPO_BRANCH) --build-arg BUILDKIT_CONTEXT_KEEP_GIT_DIR=true --build-arg CFLAGS='' --build-arg CXXFLAGS='-stdlib=libc++' --build-arg CONFIGURE_FLAGS='--disable-tests'
	docker build --platform linux/amd64 -t stellar-horizon:dev -f services/horizon/docker/Dockerfile.dev --target builder https://github.com/stellar/go.git#$(GO_REPO_BRANCH)
	docker build --platform linux/amd64 -t stellar-friendbot:dev -f services/friendbot/docker/Dockerfile https://github.com/stellar/go.git#$(GO_REPO_BRANCH)
	docker build --platform linux/amd64 -t stellar-soroban-rpc:dev -f exp/services/soroban-rpc/docker/Dockerfile https://github.com/stellar/go.git#$(GO_REPO_BRANCH)

build-dev: build-dev-deps
	docker build --platform linux/amd64 -t stellar/quickstart:dev -f Dockerfile.dev . --build-arg STELLAR_CORE_IMAGE_REF=stellar-core:dev --build-arg HORIZON_IMAGE_REF=stellar-horizon:dev --build-arg FRIENDBOT_IMAGE_REF=stellar-friendbot:dev --build-arg SOROBAN_RPC_IMAGE_REF=stellar-soroban-rpc:dev
