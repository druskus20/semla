import gleam/io
import gleam/string
import lib/config.{type Config}
import lib/db.{type DbState}
import lib/utils.{expect, redirect_to_url}
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html.{a, button, div, h1, p}
import lustre/event.{on_click}
import rsvp
import supa/auth as supa_auth

type Model {
  Model(db_state: DbState, config: Config)
}

type Msg {
  CheckSession
  SessionFromUrl(result: Result(#(supa_auth.Session, supa_auth.User), String))
  SignInWithGitHub
  GitHubAuthResponse(result: Result(String, rsvp.Error))
}

pub fn start_lustre_app(config: Config) {
  let app = lustre.application(fn(_) { init(config) }, update, view)
  case lustre.start(app, "#app", Nil) {
    Ok(_) -> Nil
    Error(e) -> {
      io.println("Failed to start lustre app: " <> string.inspect(e))
    }
  }
}

fn init(config: Config) -> #(Model, Effect(Msg)) {
  let db_state =
    db.init_connection(config) |> expect("Failed to initialize database")

  case db.is_local_mode(db_state) {
    True -> {
      let redirect_effect =
        effect.from(fn(_) { redirect_to_url("/index.html") })
      let model = Model(db_state, config)
      #(model, redirect_effect)
    }
    False -> {
      let check_session_effect = db.get_session_from_url(SessionFromUrl)
      let model = Model(db_state, config)
      #(model, check_session_effect)
    }
  }
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    CheckSession -> {
      let check_session_effect = db.get_session_from_url(SessionFromUrl)
      #(model, check_session_effect)
    }
    SessionFromUrl(result) -> {
      let Model(db_state, config) = model
      let new_db_state = db.handle_session_result(db_state, result)

      let redirect_effect = case new_db_state.auth_status {
        db.Authenticated(_) -> {
          effect.from(fn(_) { redirect_to_url("/index.html") })
        }
        _ -> {
          effect.none()
        }
      }

      #(Model(new_db_state, config), redirect_effect)
    }
    SignInWithGitHub -> {
      let Model(db_state, config) = model
      let auth_redirect_url = case config {
        config.Db(_, auth_redirect_url:) -> auth_redirect_url
        config.Local(auth_redirect_url:) -> auth_redirect_url
      }
      let effect =
        db.sign_in_with_github(db_state, auth_redirect_url, GitHubAuthResponse)
      #(model, effect)
    }
    GitHubAuthResponse(result) -> {
      let Model(db_state, config) = model
      let new_db_state = db.handle_github_auth_result(db_state, result)
      #(Model(new_db_state, config), effect.none())
    }
  }
}

fn view(model: Model) -> Element(Msg) {
  let Model(db_state, _) = model

  case db_state.auth_status {
    db.Authenticated(db.RemoteAuth(_, user)) -> {
      div([], [
        h1([], [element.text("Login Successful!")]),
        p([], [element.text("Welcome, " <> user.email <> "!")]),
        p([], [element.text("You can now visit the main app at ")]),
        a([attribute.href("/")], [element.text("/")]),
      ])
    }
    db.Authenticated(db.LocalAuth(_)) -> {
      div([], [
        h1([], [element.text("Login Successful!")]),
        p([], [element.text("Welcome, local user!")]),
        p([], [element.text("You can now visit the main app at ")]),
        a([attribute.href("/")], [element.text("/")]),
      ])
    }
    db.Loading -> {
      div([], [
        h1([], [element.text("Welcome to Semla")]),
        p([], [element.text("Loading...")]),
      ])
    }
    db.SigningOut -> {
      div([], [
        h1([], [element.text("Welcome to Semla")]),
        p([], [element.text("Signing out...")]),
      ])
    }
    db.NotAuthenticated -> {
      div([], [
        h1([], [element.text("Welcome to Semla")]),
        p([], [element.text("Please sign in to continue")]),
        button([on_click(SignInWithGitHub)], [
          element.text("Sign in with GitHub"),
        ]),
      ])
    }
    db.AuthenticationError(error) -> {
      div([], [
        h1([], [element.text("Authentication Error")]),
        p([], [element.text("Authentication failed: " <> error)]),
        button([on_click(SignInWithGitHub)], [element.text("Try again")]),
      ])
    }
  }
}
