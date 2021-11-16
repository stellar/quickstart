__PHONY__: build build-testing build-dev build-dev-deps

build:
	docker build -t stellar/quickstart -f Dockerfile .

build-testing:
	docker build -t stellar/quickstart:testing -f Dockerfile.testing .

build-dev-deps:
	# Buildkit is disabled because of https://github.com/moby/buildkit/issues/2463.
	DOCKER_BUILDKIT=0 docker build -t stellar/stellar-core:testing -f docker/Dockerfile.testing git://github.com/stellar/stellar-core#master --build-arg CFLAGS='' --build-arg CXXFLAGS='-stdlib=libc++' --build-arg CONFIGURE_FLAGS='--disable-tests'
	docker build -t stellar/stellar-horizon:dev -f services/horizon/docker/Dockerfile.dev git://github.com/stellar/go#master

build-dev: build-dev-deps
	docker build -t stellar/quickstart:dev -f Dockerfile.dev .
