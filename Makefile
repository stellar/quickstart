__PHONY__: build build-testing

build:
	docker build -t stellar/quickstart:cap21 -f Dockerfile .

run:
	docker run --rm -it -p 8000:8000 -p 11626:11626 -p 5432:5432 --name stellar stellar/quickstart:cap21 --standalone

build-testing:
	docker build -t stellar/quickstart:testing -f Dockerfile.testing .
