.SILENT:
.DEFAULT_GOAL := help

# Binaries and tools
GO          ?= go
GOPATH      ?= $(shell $(GO) env GOPATH)
GOBIN       ?= $(GOPATH)/bin
GOSEC       ?= $(GOBIN)/gosec
GOFMT       ?= $(GO) fmt
GOIMPORTS   ?= goimports -w
STATICCHECK ?= $(GOBIN)/staticcheck

# OS detection for Linux/Mac compatibility
UNAME := $(shell uname)
ifeq ($(UNAME), Darwin)
	LN_CMD       := gln
	READLINK_CMD := greadlink
else ifeq ($(UNAME), Linux)
	LN_CMD       := ln
	READLINK_CMD := readlink
else
	LN_CMD       := ln
	READLINK_CMD := readlink
endif

STAGE := .stage
STAGE := $(shell $(READLINK_CMD) -f "$(STAGE)")

GO_APP     := upgrader-coordinator
GO_APP_CMD := ./cmd

PROJECT := Forge Orchestrator

# Colors for help output
COLOR_RESET  := \033[0;39;49m
COLOR_BOLD   := \033[1m
COLOR_BLUE   := \033[38;5;81m
COLOR_YELO   := \033[38;5;227m

## Builds binary for Linux AMD64
build:
	GO111MODULE=on GOOS=linux GOARCH=amd64 $(GO) build -o $(STAGE)/$(GO_APP).linux.amd64 $(GO_APP_CMD)

## Compresses binary into tar.gz archive
compact-build:
	cd $(STAGE) && tar -zcvf $(GO_APP).linux.amd64.tar.gz $(GO_APP).linux.amd64

## Updates dependencies and verifies module integrity
check-deps:
	cd internal $(GO) get -u ./... && $(GO) mod tidy && $(GO) mod verify
	cd ui $(GO) get -u ./... && $(GO) mod tidy && $(GO) mod verify

## Downloads dependencies into vendor folder
vendor:
	$(GO) mod vendor

## Runs go fmt on all Go source files
fmt:
	cd internal $(GO) && $(GOFMT) ./...
	cd ui $(GO) && $(GOFMT) ./...

## Runs goimports on all Go source files (format + imports fix)
goimports:
	$(GOIMPORTS)

## Runs Docker Compose up in detached mode for development environment
compose-up:
	docker compose -f development/docker-compose.yml up -d

## Runs all Go tests
tests:
	$(GO) test ./internal/...
	$(GO) test ./ui/...

## Shows this help message
help:
	@echo
	@echo  "$(COLOR_YELO)$(PROJECT)$(COLOR_RESET)"
	@echo  "----------------------------------------"
	@echo  "$(COLOR_BOLD)Usage:$(COLOR_RESET) make $(COLOR_BLUE)<target>$(COLOR_RESET)"
	@echo
	@echo  "$(COLOR_BOLD)Available targets:$(COLOR_RESET)"
	awk '/^[a-zA-Z\-\_0-9\.%]+:/ { \
		helpMessage = match(lastLine, /^## (.*)/); \
		if (helpMessage) { \
			helpCommand = substr($$1, 0, index($$1, ":")-1); \
			helpMessage = substr(lastLine, RSTART + 3, RLENGTH); \
			printf "${COLOR_BLUE}    make %-30s${COLOR_RESET} %s\n", helpCommand, helpMessage; \
		} \
	} \
	{ lastLine = $$0 }' $(MAKEFILE_LIST) | sort
	@echo
