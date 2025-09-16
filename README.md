# mist_reload

Reload your mist webserver on file changes.
Includes livereloading of the browser.

[![Package Version](https://img.shields.io/hexpm/v/mist_reload)](https://hex.pm/packages/mist_reload)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/mist_reload/)

```sh
gleam add --dev mist_reload@1
```

## Example

*This example uses wisp but any mist based webserver will work.*

To create our basic application we need a server and a router.

```gleam
// src/myapp/router.gleam

import wisp

pub fn route(request, _context) {
  case request {
    _ ->
      wisp.html_response(
        "<html><head></head><body><h1>Hello!</h1></body></html>",
        200,
      )
  }
}

```

The router must be a separate module to the server so that it gets compiles to an external function call.
This is required for erlangs code reloading to take effect.

```gleam
// src/myapp/server.gleam

import mist
import myapp/router
import wisp
import wisp/wisp_mist

pub fn start(wrap_reload) {
  wisp.configure_logger()

  let context = Nil
  let secret_key_base = ""
  router.route(_, context)
  |> wisp_mist.handler(secret_key_base)
  |> wrap_reload()
  |> mist.new
  |> mist.bind("0.0.0.0")
  |> mist.port(8080)
  |> mist.start
}
```

The `wrap_reload` function is passed as an argument, rather than using a boolean value for dev/prod.
This is needed as `mist_reload` is a dev dependency and so cannot be imported in any src modules.

Next we create the function for our entry file for dev.

```gleam
// dev/myapp_dev.gleam

import gleam/erlang/process
import mist/reload
import myapp/server

pub fn main() {
  let assert Ok(_) = server.start(reload.wrap)
  process.sleep_forever()
}
```

Start your dev server with `gleam dev`

Finally we need to be able to run our server without reload for production.

```gleam
// src/myapp.gleam

import gleam/erlang/process
import mist/reload
import myapp/server

pub fn main() {
  let assert Ok(_) = server.start(fn(h) { h })
  process.sleep_forever()
}
```

Start your server with `gleam run`. There will be no code reloading

Further documentation can be found at <https://hexdocs.pm/mist_reload>.

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
```
