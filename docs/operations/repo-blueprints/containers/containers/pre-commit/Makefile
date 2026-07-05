IMAGE_NAME ?= pre-commit
REGISTRY ?= example.com/forge
IMAGE_TAG ?= local

.PHONY: build push
build:
	docker build -t $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG) .

push:
	docker push $(REGISTRY)/$(IMAGE_NAME):$(IMAGE_TAG)
