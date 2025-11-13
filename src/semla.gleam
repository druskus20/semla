import gleam/result.{try}
import index
import lib/config.{Db, Local, read_from_env}
import lib/utils.{dbg, error, get_current_path}
import login

pub fn main() {
  case run() {
    Ok(_) -> Nil
    Error(e) -> {
      error("Application error: " <> e)
    }
  }
}

pub fn run() -> Result(Nil, String) {
  use config <- try(read_from_env())

  case config {
    Local(_) -> {
      dbg(config)
    }
    Db(_, _) -> {
      dbg(config)
    }
  }

  case get_current_path() {
    "/login.html" | "/login" -> {
      login.start_lustre_app(config)
    }
    "/index.html" | "/index" | "/" -> {
      index.start_lustre_app(config)
    }
    _ -> {
      error("Not Found: The requested path does not exist.")
    }
  }

  Ok(Nil)
}
