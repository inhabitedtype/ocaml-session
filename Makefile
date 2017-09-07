.PHONY: all build test clean examples

build:
	jbuilder build --dev @install

all: build

test:
	jbuilder runtest --dev

examples:
	jbuilder build --dev @examples/all

clean:
	jbuilder clean
