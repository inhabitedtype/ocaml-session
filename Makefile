.PHONY: all build test clean examples doc

build:
	dune build

all: build

test:
	dune runtest

examples:
	dune build @examples/all

clean:
	dune clean

doc:
	dune build @doc
