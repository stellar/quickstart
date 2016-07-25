
build-base:
	docker build -t stellar/quickstart:base -f Dockerfile.base .
build-pubnet: build-base
	docker build -t stellar/quickstart:pubnet -f pubnet/Dockerfile ./pubnet
build-testnet: build-base
	docker build -t stellar/quickstart:testnet -f testnet/Dockerfile ./testnet
build-all: build-testnet build-pubnet

__PHONY__: build-all
