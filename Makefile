__PHONY__: build build-testing build-dev build-dev-deps

build:
	docker build --platform linux/amd64 -t stellar/quickstart -f Dockerfile .

build-testing:
	docker build --platform linux/amd64 -t stellar/quickstart:testing -f Dockerfile.testing .

build-dev-deps:
	docker build -t stellar-core:protocol19 -f docker/Dockerfile.testing https://github.com/sisuresh/stellar-core.git#cap21-40-2 --build-arg BUILDKIT_CONTEXT_KEEP_GIT_DIR=true --build-arg CFLAGS='' --build-arg CXXFLAGS='-stdlib=libc++' --build-arg CONFIGURE_FLAGS='--disable-tests'
	docker build -t stellar-horizon:protocol19 -f services/horizon/docker/Dockerfile.dev https://github.com/stellar/go.git#horizon-protocol-19
	docker build -t stellar-friendbot:protocol19 -f services/friendbot/docker/Dockerfile https://github.com/stellar/go.git#horizon-protocol-19

build-dev: build-dev-deps
	docker build -t stellar/quickstart:protocol19 -f Dockerfile.dev . --build-arg STELLAR_CORE_IMAGE_REF=stellar-core:protocol19 --build-arg HORIZON_IMAGE_REF=stellar-horizon:protocol19 --build-arg FRIENDBOT_IMAGE_REF=stellar-friendbot:protocol19
