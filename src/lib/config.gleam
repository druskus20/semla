import gleam/result.{try}
import lib/utils.{from_env, ok_or, parse_bool}

pub type Config {
  Local
  Db(ConfigWithDb)
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

  case local_db {
    True -> {
      Ok(Local)
    }
    False -> {
      use #(supa_url, supa_key) <- try(db_config())
      Ok(Db(ConfigWithDb(supa_url, supa_key)))
    }
  }
}

pub fn db_config() -> Result(#(String, String), String) {
  use url <- try(from_env("SUPABASE_URL") |> ok_or("SUPABASE_URL not set"))
  use key <- try(from_env("SUPABASE_KEY") |> ok_or("SUPABASE_KEY not set"))
  Ok(#(url, key))
}
