NAME := jcli
CGO_ENABLED = 0
BUILD_GOOS=$(shell go env GOOS)
GO := go
BUILD_TARGET = build
COMMIT := $(shell git rev-parse --short HEAD)
# CHANGE_LOG := $(shell echo -n "$(shell hub release show $(shell hub release --include-drafts -L 1))" | base64)
VERSION := dev-$(shell git describe --tags $(shell git rev-list --tags --max-count=1))
BUILDFLAGS = -ldflags "-X github.com/jenkins-zh/jenkins-cli/app.version=$(VERSION) \
	-X github.com/jenkins-zh/jenkins-cli/app.commit=$(COMMIT) \
	-X github.com/jenkins-zh/jenkins-cli/app.date=$(shell date +'%Y-%m-%d')"
COVERED_MAIN_SRC_FILE=./main
PATH := $(PATH):$(PWD)/bin

.PHONY: build

build: pre-build
	GO111MODULE=on CGO_ENABLED=$(CGO_ENABLED) GOOS=$(BUILD_GOOS) GOARCH=amd64 $(GO) $(BUILD_TARGET) $(BUILDFLAGS) -o bin/$(BUILD_GOOS)/$(NAME) $(MAIN_SRC_FILE)
	chmod +x bin/$(BUILD_GOOS)/$(NAME)
	rm -rf jcli && ln -s bin/$(BUILD_GOOS)/$(NAME) jcli

darwin: pre-build
	GO111MODULE=on CGO_ENABLED=$(CGO_ENABLED) GOOS=darwin GOARCH=amd64 $(GO) $(BUILD_TARGET) $(BUILDFLAGS) -o bin/darwin/$(NAME) $(MAIN_SRC_FILE)
	chmod +x bin/darwin/$(NAME)
	rm -rf jcli && ln -s bin/darwin/$(NAME) jcli

linux: pre-build
	CGO_ENABLED=$(CGO_ENABLED) GOOS=linux GOARCH=amd64 $(GO) $(BUILD_TARGET) $(BUILDFLAGS) -o bin/linux/$(NAME) $(MAIN_SRC_FILE)
	chmod +x bin/linux/$(NAME)
	rm -rf jcli && ln -s bin/linux/$(NAME) jcli

win: pre-build
	go get github.com/inconshreveable/mousetrap
	go get github.com/mattn/go-isatty
	CGO_ENABLED=$(CGO_ENABLED) GOOS=windows GOARCH=386 $(GO) $(BUILD_TARGET) $(BUILDFLAGS) -o bin/windows/$(NAME).exe $(MAIN_SRC_FILE)

build-all: darwin linux win

init: gen-mock
gen-mock:
	go get github.com/golang/mock/gomock
	go install github.com/golang/mock/mockgen
	mockgen -destination ./mock/mhttp/roundtripper.go -package mhttp net/http RoundTripper

release: build-all
	mkdir -p release
	cd ./bin/darwin; upx jcli; tar -zcvf ../../release/jcli-darwin-amd64.tar.gz jcli; cd ../../release/; shasum -a 256 jcli-darwin-amd64.tar.gz > jcli-darwin-amd64.txt
	cd ./bin/linux; upx jcli; tar -zcvf ../../release/jcli-linux-amd64.tar.gz jcli; cd ../../release/; shasum -a 256 jcli-linux-amd64.tar.gz > jcli-linux-amd64.txt
	cd ./bin/windows; upx jcli.exe; tar -zcvf ../../release/jcli-windows-386.tar.gz jcli.exe; cd ../../release/; shasum -a 256 jcli-windows-386.tar.gz > jcli-windows-386.txt

clean: ## Clean the generated artifacts
	rm -rf bin release
	rm -rf coverage.out
	rm -rf app/cmd/test-app.xml
	rm -rf app/test-app.xml
	rm -rf util/test-utils.xml

copy: darwin
	sudo cp bin/darwin/$(NAME) /usr/local/bin/jcli

copy-linux: linux
	cp bin/linux/$(NAME) /usr/local/bin/jcli

get-golint:
	go get -u golang.org/x/lint/golint

tools: i18n-tools get-golint

i18n-tools:
	go get -u github.com/gosexy/gettext/go-xgettext
# 	go get -u github.com/go-bindata/go-bindata/...
# 	go get -u github.com/kevinburke/go-bindata/...

go-bindata-download-linux:
	mkdir -p bin
	curl -L https://github.com/kevinburke/go-bindata/releases/download/v3.11.0/go-bindata-linux-amd64 -o bin/go-bindata
	chmod u+x bin/go-bindata

gen-data-linux: go-bindata-download-linux
	cd app/i18n && ../../bin/go-bindata -o bindata.go -pkg i18n jcli/zh_CN/LC_MESSAGES/

go-bindata-download-darwin:
	mkdir -p bin
	curl -L https://github.com/kevinburke/go-bindata/releases/download/v3.11.0/go-bindata-darwin-amd64 -o bin/go-bindata
	chmod u+x bin/go-bindata

gen-data-darwin: go-bindata-download-darwin
	cd app/i18n && ../../bin/go-bindata -o bindata.go -pkg i18n jcli/zh_CN/LC_MESSAGES/

verify: dep tools lint

pre-build: fmt vet
	export GO111MODULE=on
	export GOPROXY=https://goproxy.io
	go mod tidy

vet:
	go vet ./...

lint: vet
	golint -set_exit_status app/cmd/...
	golint -set_exit_status app/helper/...
	golint -set_exit_status app/i18n/i18n.go
	golint -set_exit_status app/.
	golint -set_exit_status client/...
	golint -set_exit_status util/...

fmt:
	go fmt ./util/...
	go fmt ./client/...
	go fmt ./app/...
	gofmt -s -w .

test-slow:
#	JENKINS_VERSION=2.190.3 go test ./e2e/... -v -count=1 -parallel 1
	JENKINS_VERSION=2.190.3 go test github.com/jenkins-zh/jenkins-cli/e2e -v -test.run ^TestBashCompletion$
	JENKINS_VERSION=2.190.3 go test github.com/jenkins-zh/jenkins-cli/e2e -v -test.run ^TestZshCompletion$
	JENKINS_VERSION=2.190.3 go test github.com/jenkins-zh/jenkins-cli/e2e -v -test.run ^TestPowerShellCompletion$
	JENKINS_VERSION=2.190.3 go test github.com/jenkins-zh/jenkins-cli/e2e -v -test.run ^TestListComputers$
	JENKINS_VERSION=2.190.3 go test github.com/jenkins-zh/jenkins-cli/e2e -v -test.run ^TestConfigList$
	JENKINS_VERSION=2.190.3 go test github.com/jenkins-zh/jenkins-cli/e2e -v -test.run ^TestConfigGenerate$
	JENKINS_VERSION=2.190.3 go test github.com/jenkins-zh/jenkins-cli/e2e -v -test.run ^TestConfigList$
	JENKINS_VERSION=2.190.3 go test github.com/jenkins-zh/jenkins-cli/e2e -v -test.run ^TestShowCurrentConfig$
	JENKINS_VERSION=2.190.3 go test github.com/jenkins-zh/jenkins-cli/e2e -v -test.run ^TestCrumb$
	JENKINS_VERSION=2.190.3 go test github.com/jenkins-zh/jenkins-cli/e2e -v -test.run ^TestDoc$
	JENKINS_VERSION=2.190.3 go test github.com/jenkins-zh/jenkins-cli/e2e -v -test.run ^TestSearchPlugins$
	JENKINS_VERSION=2.190.3 go test github.com/jenkins-zh/jenkins-cli/e2e -v -test.run ^TestListPlugins$
	JENKINS_VERSION=2.190.3 go test github.com/jenkins-zh/jenkins-cli/e2e -v -test.run ^TestCheckUpdateCenter$
	JENKINS_VERSION=2.190.3 go test github.com/jenkins-zh/jenkins-cli/e2e -v -test.run ^TestInstallPlugin$
	JENKINS_VERSION=2.190.3 go test github.com/jenkins-zh/jenkins-cli/e2e -v -test.run ^TestDownloadPlugin$
	JENKINS_VERSION=2.190.3 go test github.com/jenkins-zh/jenkins-cli/e2e -v -test.run ^TestListQueue$

test:
	mkdir -p bin
	go test ./util ./client ./app/ ./app/health ./app/helper ./app/i18n ./app/cmd/common -v -count=1 -coverprofile coverage.out
	go test ./app/cmd -v -count=1
#	go test ./util -v -count=1
#	go test ./client -v -count=1 -coverprofile coverage.out
#	go test ./app -v -count=1
#	go test ./app/health -v -count=1
#	go test ./app/helper -v -count=1
#	go test ./app/i18n -v -count=1
#	go test ./app/cmd -v -count=1

test-release:
	goreleaser release --rm-dist --snapshot --skip-publish

dep:
	go get github.com/AlecAivazis/survey/v2
	go get github.com/spf13/cobra
	go get github.com/spf13/viper
	go get gopkg.in/yaml.v2
	go get github.com/Pallinder/go-randomdata
	go install github.com/gosuri/uiprogress

JCLI_FILES="app/cmd/*.go"
gettext:
	go-xgettext -k=i18n.T "${JCLI_FILES}" > app/i18n/jcli.pot

gen-data:
	cd app/i18n && go-bindata -o bindata.go -pkg i18n jcli/zh_CN/LC_MESSAGES/

image:
	docker build . -t jenkinszh/jcli

setup-env-centos:
	yum install make golang -y
