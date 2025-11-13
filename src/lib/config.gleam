import gleam/result.{try}
import lib/utils.{from_env, ok_or, parse_bool}

pub type Config {
  Local(auth_redirect_url: String)
  Db(ConfigWithDb, auth_redirect_url: String)
}

pub type ConfigWithDb {
  ConfigWithDb(supa_url: String, supa_key: String)
}

pub fn read_from_env() -> Result(Config, String) {
  use local_db <- try(
    from_env("LOCAL_DB")
    |> ok_or("LOCAL_DB not set")
    |> try(parse_bool),
  )

  use auth_redirect_url <- try(
    from_env("AUTH_REDIRECT_URL")
    |> ok_or("AUTH_REDIRECT_URL not set"),
  )

  case local_db {
    True -> {
      Ok(Local(auth_redirect_url))
    }
    False -> {
      use #(supa_url, supa_key) <- try(db_config())
      Ok(Db(ConfigWithDb(supa_url, supa_key), auth_redirect_url))
    }
  }
}

pub fn db_config() -> Result(#(String, String), String) {
  use url <- try(from_env("SUPABASE_URL") |> ok_or("SUPABASE_URL not set"))
  use key <- try(
    from_env("SUPABASE_ANON_KEY") |> ok_or("SUPABASE_ANON_KEY not set"),
  )
  Ok(#(url, key))
}
