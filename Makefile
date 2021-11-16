__PHONY__: build build-testing

build:
	docker build -t stellar/quickstart -f Dockerfile .

build-testing:
	docker build -t stellar/quickstart:testing -f Dockerfile.testing .

generate-workflows:
	cd .github/workflow-templates && ruby ./generate.rb test.yml > ../workflows/test.yml
