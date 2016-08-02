__PHONY__: build

build:
	docker build -t stellar/quickstart -f Dockerfile .
