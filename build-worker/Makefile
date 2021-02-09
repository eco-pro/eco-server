NS = eco-pro
VERSION ?= v1
REPO = eco-server-build-worker

.PHONY: build push release

build:
	docker build -t $(NS)/$(REPO):$(VERSION) .

push:
	docker push $(NS)/$(REPO):$(VERSION)

release: build
	make push -e VERSION=$(VERSION)

default: build
