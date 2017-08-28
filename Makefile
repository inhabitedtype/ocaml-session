.PHONY: all test clean examples

all:
	jbuilder build --dev

test:
	jbuilder runtest --dev

examples:
	jbuilder build @examples/all

clean:
	jbuilder clean
