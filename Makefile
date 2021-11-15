__PHONY__: build build-testing build-dev

build:
	docker build -t stellar/quickstart -f Dockerfile .

build-testing:
	docker build -t stellar/quickstart:testing -f Dockerfile.testing .

build-dev:
	docker build -t stellar/stellar-core:testing -f docker/Dockerfile.testing git://github.com/stellar/stellar-core-experimental-cap21and40#cap21and40 --build-arg CFLAGS='' --build-arg CXXFLAGS='-stdlib=libc++' --build-arg CONFIGURE_FLAGS='--disable-tests'
	docker build -t stellar/stellar-horizon:dev -f services/horizon/docker/Dockerfile.dev git://github.com/stellar/go#cap21and40
	docker build -t stellar/quickstart:dev -f Dockerfile.dev .
