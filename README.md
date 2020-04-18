# ocaml-session

ocaml-session is an session manager that handles cookie headers and backend
storage for HTTP servers. The library supports [CoHTTP][] and [Webmachine][];
[Async][] and [Lwt][]; and pluggable backing stores based on a functor
interface.

[![Build Status](https://travis-ci.org/inhabitedtype/ocaml-session.svg?branch=master)](https://travis-ci.org/inhabitedtype/ocaml-session)


[CoHTTP]: https://github.com/mirage/ocaml-cohttp
[Webmachine]: https://github.com/inhabitedtype/ocaml-webmachine
[Async]: https://ocaml.janestreet.com/ocaml-core/111.28.00/doc/
[Lwt]: http://ocsigen.org/lwt/

## Installation

Install the library and its depenencies via [OPAM][opam]:

[opam]: http://opam.ocaml.org/

```bash
opam install session
```

## Basic Usage

Below is a simplified implementation of session-based user authentication, one
of the most common use-cases of sessions. The server will respond with `401
Unauthorized` for every path until the client visits `/authenticate`, after
which all paths will respond with `200 OK`.

```ocaml
module Session = struct
  module Backend = Session_postgresql_lwt
  include Session
  include Session_cohttp_lwt.Make(Backend)
end

let cookie_key = "__session"

let callback conn { Request.headers; uri } body =
  Session.of_header backend cookie_key headers
  >>= function
    | Ok (Some session) when authorized session ->
      Server.respond ~status:`OK ()
    | _ ->
      if Uri.path = "/authenticate" then
        let session = Session.generate backend "<user_id>" in
        let headers = Header.of_list (Session.to_cookie_hdrs cookie_key session) in
        Server.respond ~headers ~status:`OK ()
      else
        Server.respond ~status:`Unauthorized ()
```

There are additional examples for both CoHTTP and webmachine in the
[examples][] subdirectory of this project. These examples use a session to
count the number of HTTP requests that the server has received from a client.
To build them, reconfigure the build to enable examples, an i/o library of our
choice (e.g., Async or Lwt), as well as the library you're using to build your
server (e.g., CoHTTP or Webmachine):

[examples]: https://github.com/inhabitedtype/tree/master/examples

```bash
./configure --enable-examples --enable-async --enable-cohttp
make
```

## Development

To install development versions of the library, pin the package from the root
of the repository:

```bash
opam pin add .
```

You can install the latest changes by committing them to the local git
repository and running:

```bash
opam upgrade session
```

For building and running the tests during development, you will need to install
the `oUnit` package and reconfigure the build process to enable tests:

```bash
opam install oUnit
./configure --enable-tests
make && make test
```

## License

BSD3, see LICENSE file for its text.
