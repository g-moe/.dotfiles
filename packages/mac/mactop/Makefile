.PHONY: build run test verify clean

APP_NAME := mactop

build:
	go build -trimpath -o $(APP_NAME) .

run:
	go run main.go

test:
	go test ./...

verify:
	go test ./... -count=1
	go test -race ./... -count=1
	go vet ./...
	go build ./...
	go test ./... -shuffle=on -count=3

clean:
	rm -f $(APP_NAME)

modernize:
	go run golang.org/x/tools/go/analysis/passes/modernize/cmd/modernize@latest -fix ./...

sexy:
	go fmt ./...
	go vet ./...
	$$(go env GOPATH)/bin/gocyclo -over 15 .
	$$(go env GOPATH)/bin/ineffassign ./...
