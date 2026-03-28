import filepath
import gleam/bit_array
import gleam/bytes_tree
import gleam/erlang/process
import gleam/http/request
import gleam/http/response
import gleam/otp/actor
import gleam/set
import gleam/string
import gleam/string_tree
import mist
import radiate
import simplifile

type Message(t) {
  Register(subscriber: process.Subject(t), reply: process.Subject(Nil))
  Broadcast(t)
}

pub fn wrap(handler) {
  let assert Ok(registry) =
    actor.new(set.new())
    |> actor.on_message(fn(state, message) {
      case message {
        Register(subscriber, reply) -> {
          actor.send(reply, Nil)
          set.insert(state, subscriber)
          |> actor.continue
        }
        Broadcast(payload) -> {
          set.each(state, fn(pid) { actor.send(pid, payload) })
          actor.continue(state)
        }
      }
    })
    |> actor.start()

  let assert Ok(current_directory) = simplifile.current_directory()
  let src_directory = filepath.join(current_directory, "src")

  let _ =
    radiate.new()
    |> radiate.add_dir(src_directory)
    |> radiate.on_reload(fn(_state: Nil, _file) {
      actor.send(registry.data, Broadcast(Reloaded))
    })
    |> radiate.start()
  debug_handler(registry.data, handler)
}

const debug_script = "<script>
  let reloading = false;
  const source = new EventSource(\"/_reload\");
  source.onmessage = (e) => {
    if (reloading) return;
    reloading = true;
    globalThis.setTimeout(() => window.location.reload(), 200);
  }
</script>"

fn debug_handler(registry, handler) {
  fn(request) {
    let response = case request.path_segments(request) {
      ["_reload"] -> reload(registry, request)
      _ -> {
        handler(request)
      }
    }
    // No byte_tree replace
    case response.body {
      mist.Websocket(..) -> response
      mist.Bytes(tree) ->
        case response.get_header(response, "content-type") {
          Ok("text/html" <> _) -> {
            let binary = bytes_tree.to_bit_array(tree)
            case bit_array.to_string(binary) {
              Ok(html) ->
                html
                |> string.replace("</head>", debug_script <> "</head>")
                |> bytes_tree.from_string
                |> mist.Bytes
                |> response.set_body(response, _)
              Error(_) -> response
            }
          }
          _ -> response
        }
      // This could be HTML but not yet in my usecase
      mist.Chunked(..) -> response
      // If files are updated the latest will already be served
      mist.File(..) -> response
      mist.ServerSentEvents(..) -> response
    }
  }
}

/// See `mist.send_file` to use this response type.
fn reload(registry, request) {
  let init = fn(self) {
    let Nil = actor.call(registry, 10, Register(self, _))
    Ok(actor.initialised(Nil))
  }

  mist.server_sent_events(request, response.new(200), init:, loop:)
}

type ReloadMessage {
  Reloaded
}

fn loop(state, message, conn) {
  case message {
    Reloaded -> {
      let _ =
        mist.send_event(conn, mist.event(string_tree.from_string("reload")))
      actor.continue(state)
    }
  }
}
// lustre-dev-tools uses fs directly
// file spy adds initialize etc
// fn(r) {
//   let response = router(r)
//   echo response
//   case
//     response.get_header(response, "content-type"),
//     response.body
//   {
//     Ok("text/html" <> _), wisp.Text(html) ->
//       html
//       |> string.replace("</head>", debug_script <> "</head>")
//       |> wisp.Text
//       |> response.set_body(response, _)
//     _, _ -> response
//   }
// },
