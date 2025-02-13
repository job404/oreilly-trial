ERRCHECK_VERSION ?= latest
GOLANGCI_LINT_VERSION ?= latest
REVIVE_VERSION ?= latest
GOIMPORTS_VERSION ?= latest
INEFFASSIGN_VERSION ?= latest

LOCAL_BIN := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))/.bin

.PHONY: all
all: clean tools lint fmt test build

.PHONY: clean
clean:
	rm -rf $(LOCAL_BIN)

.PHONY: pre-commit-setup
pre-commit-setup:
	#python3 -m venv venv
	#source venv/bin/activate
	#pip3 install pre-commit
	pre-commit install -c build/ci/.pre-commit-config.yaml

.PHONY: tools
tools:  golangci-lint-install revive-install go-imports-install ineffassign-install errcheck-install
	go mod tidy

.PHONY: golangci-lint-install
golangci-lint-install:
	GOBIN=$(LOCAL_BIN) go install github.com/golangci/golangci-lint/cmd/golangci-lint@$(GOLANGCI_LINT_VERSION)

.PHONY: revive-install
revive-install:
	GOBIN=$(LOCAL_BIN) go install github.com/mgechev/revive@$(REVIVE_VERSION)

.PHONY: ineffassign-install
ineffassign-install:
	GOBIN=$(LOCAL_BIN) go install github.com/gordonklaus/ineffassign@$(INEFFASSIGN_VERSION)

.PHONY: errcheck-install
errcheck-install:
	GOBIN=$(LOCAL_BIN) go install github.com/kisielk/errcheck@$(ERRCHECK_VERSION)

.PHONY: lint
lint: tools run-lint

.PHONY: run-lint
run-lint: lint-golangci-lint lint-revive

.PHONY: lint-golangci-lint
lint-golangci-lint:
	$(info running golangci-lint...)
	$(LOCAL_BIN)/golangci-lint -v run ./... || (echo golangci-lint returned an error, exiting!; sh -c 'exit 1';)

.PHONY: lint-revive
lint-revive:
	$(info running revive...)
	$(LOCAL_BIN)/revive -formatter=stylish -config=build/ci/.revive.toml -exclude ./vendor/... ./... || (echo revive returned an error, exiting!; sh -c 'exit 1';)

.PHONY: upgrade-direct-deps
upgrade-direct-deps: tidy
	for item in `grep -v 'indirect' go.mod | grep '/' | cut -d ' ' -f 1`; do \
		echo "trying to upgrade direct dependency $$item" ; \
		go get -u $$item ; \
  	done
	go mod tidy
	go mod vendor

.PHONY: tidy
tidy:
	go mod tidy

.PHONY: run-goimports
run-goimports: go-imports-install
	for item in `find . -type f -name '*.go' -not -path './vendor/*'`; do \
		$(LOCAL_BIN)/goimports -l -w $$item ; \
	done

.PHONY: go-imports-install
go-imports-install:
	GOBIN=$(LOCAL_BIN) go install golang.org/x/tools/cmd/goimports@$(GOIMPORTS_VERSION)

.PHONY: fmt
fmt: tools run-errcheck run-fmt run-ineffassign run-vet

.PHONY: run-errcheck
run-errcheck:
	$(info running errcheck...)
	$(LOCAL_BIN)/errcheck ./... || (echo errcheck returned an error, exiting!; sh -c 'exit 1';)

.PHONY: run-fmt
run-fmt:
	$(info running fmt...)
	go fmt ./... || (echo fmt returned an error, exiting!; sh -c 'exit 1';)

.PHONY: run-ineffassign
run-ineffassign:
	$(info running ineffassign...)
	$(LOCAL_BIN)/ineffassign ./... || (echo ineffassign returned an error, exiting!; sh -c 'exit 1';)

.PHONY: run-vet
run-vet:
	$(info running vet...)
	go vet ./... || (echo vet returned an error, exiting!; sh -c 'exit 1';)

.PHONY: test
test: tidy
	$(info starting the test for whole module...)
	go test -tags "unit e2e integration" -failfast -vet=off -race -coverprofile=all_coverage.txt -covermode=atomic ./... -ldflags="-X github.com/bilalcaliskan/oreilly-trial/internal/mail.token=${API_TOKEN}" || (echo an error while testing, exiting!; sh -c 'exit 1';)

.PHONY: test-unit
test-unit: tidy
	$(info starting the unit test for whole module...)
	go test -tags "unit" -failfast -vet=off -race -coverprofile=unit_coverage.txt -covermode=atomic ./... -ldflags="-X github.com/bilalcaliskan/oreilly-trial/internal/mail.token=${API_TOKEN}" || (echo an error while testing, exiting!; sh -c 'exit 1';)

.PHONY: test-e2e
test-e2e: tidy
	$(info starting the e2e test for whole module...)
	go test -tags "e2e" -failfast -vet=off -race -coverprofile=e2e_coverage.txt -covermode=atomic ./... -ldflags="-X github.com/bilalcaliskan/oreilly-trial/internal/mail.token=${API_TOKEN}" || (echo an error while testing, exiting!; sh -c 'exit 1';)

.PHONY: test-integration
test-integration: tidy
	$(info starting the integration test for whole module...)
	go test -tags "integration" -failfast -vet=off -race -coverprofile=integration_coverage.txt -covermode=atomic ./... -ldflags="-X github.com/bilalcaliskan/oreilly-trial/internal/mail.token=${API_TOKEN}" || (echo an error while testing, exiting!; sh -c 'exit 1';)

.PHONY: update
update: tidy
	go get -u ./...

.PHONY: build
build: tidy
	$(info building binary...)
	go build -ldflags="-X github.com/bilalcaliskan/oreilly-trial/internal/mail.token=${API_TOKEN}" -o bin/main main.go || (echo an error while building binary, exiting!; sh -c 'exit 1';)

.PHONY: run
run: tidy
	go run main.go

.PHONY: cross-compile
cross-compile:
	GOOS=freebsd GOARCH=386 go build -o bin/main-freebsd-386 main.go
	GOOS=darwin GOARCH=386 go build -o bin/main-darwin-386 main.go
	GOOS=linux GOARCH=386 go build -o bin/main-linux-386 main.go
	GOOS=windows GOARCH=386 go build -o bin/main-windows-386 main.go
	GOOS=freebsd GOARCH=amd64 go build -o bin/main-freebsd-amd64 main.go
	GOOS=darwin GOARCH=amd64 go build -o bin/main-darwin-amd64 main.go
	GOOS=linux GOARCH=amd64 go build -o bin/main-linux-amd64 main.go
	GOOS=windows GOARCH=amd64 go build -o bin/main-windows-amd64 main.go
