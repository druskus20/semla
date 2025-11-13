import lib/config.{type Config}
import lib/utils
import lustre/effect.{type Effect}
import rsvp
import supa/auth
import supa/client

pub type DbConnection {
  LocalConnection
  RemoteConnection(client: client.Client)
}

pub type DbAuth {
  LocalAuth(user_id: String)
  RemoteAuth(session: auth.Session, user: auth.User)
}

pub type AuthStatus {
  Loading
  NotAuthenticated
  Authenticated(auth: DbAuth)
  AuthenticationError(error: String)
  SigningOut
}

pub type DbState {
  DbState(connection: DbConnection, auth_status: AuthStatus)
}

pub fn init_connection(config: Config) -> Result(DbState, String) {
  case config {
    config.Local(_) -> {
      let state =
        DbState(LocalConnection, Authenticated(LocalAuth("local_user")))
      Ok(state)
    }
    config.Db(db_config, _) -> {
      let client = client.create(db_config.supa_url, db_config.supa_key)
      let state = DbState(RemoteConnection(client), Loading)
      Ok(state)
    }
  }
}

pub fn sign_in_with_email(
  state: DbState,
  email: String,
  handler: fn(Result(Nil, rsvp.Error)) -> msg,
) -> Effect(msg) {
  case state.connection {
    LocalConnection -> {
      panic as "sign_in_with_email should not be called in local mode"
    }
    RemoteConnection(client) -> {
      auth.sign_in_with_otp(client, email, True, handler)
    }
  }
}

pub fn verify_otp_code(
  state: DbState,
  email: String,
  code: String,
  handler: fn(Result(#(auth.Session, auth.User), rsvp.Error)) -> msg,
) -> Effect(msg) {
  case state.connection {
    LocalConnection -> {
      panic as "verify_otp_code should not be called in local mode"
    }
    RemoteConnection(client) -> {
      auth.verify_otp(client, email, code, handler)
    }
  }
}

pub fn sign_in_with_github(
  state: DbState,
  redirect_to: String,
  handler: fn(Result(String, rsvp.Error)) -> msg,
) -> Effect(msg) {
  case state.connection {
    LocalConnection -> {
      panic as "sign_in_with_github should not be called in local mode"
    }
    RemoteConnection(client) -> {
      auth.sign_in_with_github(client, redirect_to, effect.from, handler)
    }
  }
}

pub fn exchange_code_for_session(
  state: DbState,
  authorization_code: String,
  code_verifier: String,
  handler: fn(Result(#(auth.Session, auth.User), rsvp.Error)) -> msg,
) -> Effect(msg) {
  case state.connection {
    LocalConnection -> {
      panic as "exchange_code_for_session should not be called in local mode"
    }
    RemoteConnection(client) -> {
      auth.exchange_code_for_session(
        client,
        authorization_code,
        code_verifier,
        handler,
      )
    }
  }
}

pub fn get_session_from_url(
  handler: fn(Result(#(auth.Session, auth.User), String)) -> msg,
) -> Effect(msg) {
  auth.get_session_from_url(effect.from, handler)
}

pub fn sign_out(
  state: DbState,
  handler: fn(Result(Nil, rsvp.Error)) -> msg,
) -> Effect(msg) {
  case state.connection {
    LocalConnection -> {
      panic as "sign_out should not be called in local mode"
    }
    RemoteConnection(client) -> {
      effect.from(fn(dispatch) {
        auth.sign_out(client, fn(result) { dispatch(handler(result)) })
      })
    }
  }
}

pub fn handle_session_result(
  state: DbState,
  result: Result(#(auth.Session, auth.User), String),
) -> DbState {
  case result {
    Ok(#(session, user)) -> {
      let new_state =
        DbState(state.connection, Authenticated(RemoteAuth(session, user)))
      new_state
    }
    Error(error_msg) -> {
      utils.error("Session retrieval error: " <> error_msg)
      let new_state = DbState(state.connection, NotAuthenticated)
      new_state
    }
  }
}

pub fn handle_github_auth_result(
  state: DbState,
  result: Result(String, rsvp.Error),
) -> DbState {
  case result {
    Ok(auth_url) -> {
      utils.redirect_to_url(auth_url)
      state
    }
    Error(_) -> {
      DbState(state.connection, AuthenticationError("GitHub sign-in failed"))
    }
  }
}

pub fn start_sign_out(state: DbState) -> DbState {
  DbState(state.connection, SigningOut)
}

pub fn can_access_data(state: DbState) -> Bool {
  case state.auth_status {
    Authenticated(LocalAuth(_)) -> True
    Authenticated(RemoteAuth(_, _)) -> True
    _ -> False
  }
}

pub fn get_client(state: DbState) -> client.Client {
  case state.connection {
    LocalConnection ->
      panic as "BUG: get_client() called in local mode - this should never happen"
    RemoteConnection(client) -> client
  }
}

pub fn get_authenticated_client(state: DbState) -> Result(client.Client, String) {
  case state.connection, state.auth_status {
    LocalConnection, _ ->
      panic as "BUG: get_authenticated_client() called in local mode - this should never happen"
    RemoteConnection(client), Authenticated(RemoteAuth(session, _)) -> {
      let client.Client(host, _api_key) = client
      Ok(client.Client(host, session.access_token))
    }
    RemoteConnection(_), _ ->
      Error("Not authenticated - no access token available")
  }
}

pub fn get_user_id(state: DbState) -> Result(String, String) {
  case state.auth_status {
    Authenticated(LocalAuth(user_id)) -> Ok(user_id)
    Authenticated(RemoteAuth(_, user)) -> Ok(user.id)
    _ -> Error("Not authenticated")
  }
}

pub fn get_access_token(state: DbState) -> Result(String, String) {
  case state.auth_status {
    Authenticated(RemoteAuth(session, _)) -> Ok(session.access_token)
    Authenticated(LocalAuth(_)) -> Error("No access token in local mode")
    _ -> Error("Not authenticated")
  }
}

pub fn is_local_mode(state: DbState) -> Bool {
  case state.connection {
    LocalConnection -> True
    RemoteConnection(_) -> False
  }
}
