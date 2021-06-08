  
TARGET_IMAGE ?= "uk.icr.io/ibp-cc-example2/ibp-cc-example2:latest"

GO_VER ?= 1.14.15
ALPINE_VER ?= 3.12

BUILD_ARGS=--build-arg ALPINE_VER=${ALPINE_VER} --build-arg GO_VER=${GO_VER}

build:
	go build -o ./cc-example2 .

image:
	docker build $(BUILD_ARGS) . -t $(TARGET_IMAGE)