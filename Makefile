__PHONY__: build build-testing build-dev build-dev-deps

build:
	docker build --platform linux/amd64 -t stellar/quickstart -f Dockerfile .

build-testing:
	docker build --platform linux/amd64 -t stellar/quickstart:testing -f Dockerfile.testing .

build-dev-deps:
	docker build -t stellar-core:master -f docker/Dockerfile.testing https://github.com/stellar/stellar-core.git#master --build-arg BUILDKIT_CONTEXT_KEEP_GIT_DIR=true --build-arg CFLAGS='' --build-arg CXXFLAGS='-stdlib=libc++' --build-arg CONFIGURE_FLAGS='--disable-tests'
	docker build -t stellar-horizon:master -f services/horizon/docker/Dockerfile.dev --target builder https://github.com/stellar/go.git#master
	docker build -t stellar-friendbot:master -f services/friendbot/docker/Dockerfile https://github.com/stellar/go.git#master

build-dev: build-dev-deps
	docker build -t stellar/quickstart:dev -f Dockerfile.dev . --build-arg STELLAR_CORE_IMAGE_REF=stellar-core:master --build-arg HORIZON_IMAGE_REF=stellar-horizon:master --build-arg FRIENDBOT_IMAGE_REF=stellar-friendbot:master
