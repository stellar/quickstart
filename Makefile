__PHONY__: build-all

build-base:
	docker build -t stellar/quickstart:base -f Dockerfile .
build-pubnet: build-base
	docker build -t stellar/quickstart:pubnet -f pubnet/Dockerfile ./pubnet
build-testnet: build-base
	docker build -t stellar/quickstart:testnet -f testnet/Dockerfile ./testnet
build-all: build-testnet build-pubnet
