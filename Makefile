__PHONY__: build build-testing build-dev build-dev-deps

build:
	docker build -t stellar/quickstart -f Dockerfile .

build-testing:
	docker build -t stellar/quickstart:testing -f Dockerfile.testing .

build-dev-deps:
	docker build -t stellar-core:master -f docker/Dockerfile.testing git://github.com/stellar/stellar-core#master --build-arg BUILDKIT_CONTEXT_KEEP_GIT_DIR=true --build-arg CFLAGS='' --build-arg CXXFLAGS='-stdlib=libc++' --build-arg CONFIGURE_FLAGS='--disable-tests'
	docker build -t stellar-horizon:master -f services/horizon/docker/Dockerfile.dev git://github.com/stellar/go#master

build-dev: build-dev-deps
	docker build -t stellar/quickstart:dev -f Dockerfile.dev . --build-arg STELLAR_CORE_IMAGE_REF=stellar-core:master --build-arg HORIZON_IMAGE_REF=stellar-horizon:master
