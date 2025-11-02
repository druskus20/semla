import gleam/option.{type Option, None, Some}

pub fn from_env(key: String) -> Option(String) {
  case js_from_env(key) {
    "" -> None
    value -> Some(value)
  }
}

@external(javascript, "./utils.ffi.mjs", "fromEnv")
fn js_from_env(key: String) -> String

pub fn parse_bool(str: String) -> Result(Bool, String) {
  case str {
    "true" -> Ok(True)
    "false" -> Ok(False)
    _ -> Error("Invalid boolean string")
  }
}

pub fn dbg(v: any) -> Nil {
  dbg_js(v)
}

@external(javascript, "./utils.ffi.mjs", "dbg")
fn dbg_js(v: any) -> Nil

pub fn stringify(v: any) -> String {
  js_stringify(v)
}

@external(javascript, "./utils.ffi.mjs", "stringify")
fn js_stringify(v: any) -> String

pub fn get_current_path() -> String {
  js_get_current_path()
}

@external(javascript, "./utils.ffi.mjs", "getCurrentPath")
fn js_get_current_path() -> String

pub fn get_localstorage(key: String) -> Option(String) {
  case js_get_localstorage(key) {
    Ok(value) -> Some(value)
    Error(_) -> None
  }
}

@external(javascript, "./utils.ffi.mjs", "getLocalstorage")
fn js_get_localstorage(key: String) -> Result(String, Nil)

pub fn redirect_to_url(url: String) -> Nil {
  js_redirect_to_url(url)
}

@external(javascript, "./utils.ffi.mjs", "redirectToUrl")
fn js_redirect_to_url(url: String) -> Nil

pub fn error(msg: String) {
  js_error(msg)
}

@external(javascript, "./utils.ffi.mjs", "error")
fn js_error(msg: String) -> Nil

pub fn warn(msg: String) {
  js_warn(msg)
}

@external(javascript, "./utils.ffi.mjs", "warn")
fn js_warn(msg: String) -> Nil

pub fn info(msg: String) {
  js_info(msg)
}

@external(javascript, "./utils.ffi.mjs", "info")
fn js_info(msg: String) -> Nil

pub fn debug(msg: String) {
  js_debug(msg)
}

@external(javascript, "./utils.ffi.mjs", "debug")
fn js_debug(msg: String) -> Nil

pub fn trace(msg: String) {
  js_trace(msg)
}

@external(javascript, "./utils.ffi.mjs", "trace")
fn js_trace(msg: String) -> Nil

pub fn expect(result: Result(a, b), msg: String) -> a {
  case result {
    Ok(value) -> value
    Error(_) -> panic as msg
  }
}

pub fn unwrap(result: Result(a, b)) -> a {
  case result {
    Ok(value) -> value
    Error(_) -> panic as "called unwrap on an Error value"
  }
}

pub fn unwrap_or(result: Result(a, b), default: a) -> a {
  case result {
    Ok(value) -> value
    Error(_) -> default
  }
}

pub fn ctx(result: Result(a, String), context: String) -> Result(a, String) {
  case result {
    Ok(value) -> Ok(value)
    Error(err) -> Error(context <> ": " <> err)
  }
}

pub fn ok_or(option: Option(a), error: String) -> Result(a, String) {
  case option {
    Some(value) -> Ok(value)
    None -> Error(error)
  }
}

pub fn ok(result: Result(a, b)) -> Option(a) {
  case result {
    Ok(value) -> Some(value)
    Error(_) -> None
  }
}
