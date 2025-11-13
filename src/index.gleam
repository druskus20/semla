import gleam/io
import gleam/list
import gleam/option
import gleam/string
import lib/config.{type Config}
import lib/db.{type DbState}
import lib/todos.{type Todo, Todo}
import lib/utils.{expect, redirect_to_url}
import lustre
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html.{button, div, p}
import lustre/event.{on_click}
import optimist
import rsvp
import supa/auth as supa_auth
import views/todo_list

type Model {
  Model(
    db_state: DbState,
    todos: optimist.Optimistic(List(Todo)),
    new_todo_name: String,
  )
}

type Msg {
  SessionFromUrl(result: Result(#(supa_auth.Session, supa_auth.User), String))
  SignOut
  SignOutComplete(result: Result(Nil, rsvp.Error))

  UpdateNewTodoName(String)
  SubmitNewTodo
  ToggleTodoStatus(String)
  DeleteTodo(String)

  TodosLoaded(Result(List(Todo), String))
  TodoCreated(Result(Todo, String))
  TodoUpdated(Result(Todo, String))
  TodoDeleted(Result(Nil, String))
}

pub fn start_lustre_app(config: Config) {
  io.println("Starting index page...")
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

  let model = Model(db_state, optimist.from([]), "")

  case db.is_local_mode(db_state) {
    True -> {
      let load_todos_effect =
        todos.list_todos(db_state)
        |> effect.map(TodosLoaded)
      #(model, load_todos_effect)
    }
    False -> {
      let check_session_effect = db.get_session_from_url(SessionFromUrl)
      #(model, check_session_effect)
    }
  }
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    SessionFromUrl(result) -> {
      let Model(db_state, todos, new_todo_name) = model
      let new_db_state = db.handle_session_result(db_state, result)

      let redirect_effect = case new_db_state.auth_status {
        db.NotAuthenticated | db.AuthenticationError(_) -> {
          effect.from(fn(_) { redirect_to_url("/login.html") })
        }
        _ -> effect.none()
      }

      let load_effect = case db.can_access_data(new_db_state) {
        True -> {
          todos.list_todos(new_db_state)
          |> effect.map(TodosLoaded)
        }
        False -> effect.none()
      }

      let combined_effect = effect.batch([redirect_effect, load_effect])
      #(Model(new_db_state, todos, new_todo_name), combined_effect)
    }

    SignOut -> {
      let Model(db_state, todos, new_todo_name) = model
      let new_db_state = db.start_sign_out(db_state)
      let sign_out_effect = db.sign_out(db_state, SignOutComplete)
      #(Model(new_db_state, todos, new_todo_name), sign_out_effect)
    }

    SignOutComplete(_result) -> {
      let sign_out_redirect_effect =
        effect.from(fn(_) { redirect_to_url("/login.html") })
      #(model, sign_out_redirect_effect)
    }

    UpdateNewTodoName(name) -> {
      let Model(db_state, todos, _) = model
      #(Model(db_state, todos, name), effect.none())
    }

    SubmitNewTodo -> {
      let Model(db_state, todos, new_todo_name) = model
      case string.trim(new_todo_name) {
        name if name != "" -> {
          let current_todos = optimist.unwrap(todos)
          let temp_id = "temp-" <> name

          case list.any(current_todos, fn(task) { task.id == temp_id }) {
            True -> {
              #(model, effect.none())
            }
            False -> {
              let optimistic_todo =
                Todo(
                  id: temp_id,
                  name: name,
                  deadline: option.None,
                  status: todos.Pending,
                  user_id: "optimistic",
                )

              let updated_todos =
                optimist.push(todos, [optimistic_todo, ..current_todos])

              let create_effect =
                todos.create_todo(db_state, name, option.None, todos.Pending)
                |> effect.map(TodoCreated)

              #(Model(db_state, updated_todos, ""), create_effect)
            }
          }
        }
        _ -> {
          #(model, effect.none())
        }
      }
    }

    ToggleTodoStatus(id) -> {
      let Model(db_state, todos, new_todo_name) = model
      let current_todos = optimist.unwrap(todos)
      case list.find(current_todos, fn(item) { item.id == id }) {
        Ok(found_item) -> {
          let new_status = case found_item.status {
            todos.Pending -> todos.InProgress
            todos.InProgress -> todos.Completed
            todos.Completed -> todos.Pending
          }

          let updated_todo = Todo(..found_item, status: new_status)

          let updated_list =
            list.map(current_todos, fn(item) {
              case item.id == id {
                True -> updated_todo
                False -> item
              }
            })
          let updated_todos = optimist.push(todos, updated_list)

          let update_effect =
            todos.update_todo(
              db_state,
              id,
              found_item.name,
              found_item.deadline,
              new_status,
            )
            |> effect.map(TodoUpdated)

          #(Model(db_state, updated_todos, new_todo_name), update_effect)
        }
        Error(_) -> #(model, effect.none())
      }
    }

    DeleteTodo(id) -> {
      let Model(db_state, todos, new_todo_name) = model
      let current_todos = optimist.unwrap(todos)

      let filtered_todos =
        list.filter(current_todos, fn(item) { item.id != id })

      let updated_todos = optimist.push(todos, filtered_todos)

      let delete_effect =
        todos.delete_todo(db_state, id)
        |> effect.map(TodoDeleted)

      #(Model(db_state, updated_todos, new_todo_name), delete_effect)
    }

    TodoCreated(result) -> {
      let Model(db_state, todos, new_todo_name) = model
      case result {
        Ok(created_todo) -> {
          let current_todos = optimist.unwrap(todos)
          let updated_todos =
            list.map(current_todos, fn(item) {
              case
                string.starts_with(item.id, "temp-")
                && item.name == created_todo.name
              {
                True -> created_todo
                False -> item
              }
            })
          let new_todos = optimist.push(todos, updated_todos)
          #(
            Model(db_state, optimist.force(new_todos), new_todo_name),
            effect.none(),
          )
        }
        Error(_) -> {
          let new_todos = optimist.revert(todos)
          #(Model(db_state, new_todos, new_todo_name), effect.none())
        }
      }
    }

    TodoUpdated(result) -> {
      let Model(db_state, todos, new_todo_name) = model
      case result {
        Ok(_) -> {
          let new_todos = optimist.force(todos)
          #(Model(db_state, new_todos, new_todo_name), effect.none())
        }
        Error(_) -> {
          let new_todos = optimist.revert(todos)
          #(Model(db_state, new_todos, new_todo_name), effect.none())
        }
      }
    }

    TodoDeleted(result) -> {
      let Model(db_state, todos, new_todo_name) = model
      case result {
        Ok(_) -> {
          let new_todos = optimist.force(todos)
          #(Model(db_state, new_todos, new_todo_name), effect.none())
        }
        Error(_) -> {
          let new_todos = optimist.revert(todos)
          #(Model(db_state, new_todos, new_todo_name), effect.none())
        }
      }
    }

    TodosLoaded(result) -> {
      let Model(db_state, todos, new_todo_name) = model
      let new_todos = optimist.resolve(todos, result)
      #(Model(db_state, new_todos, new_todo_name), effect.none())
    }
  }
}

fn view(model: Model) -> Element(Msg) {
  let Model(db_state, todos, new_todo_name) = model

  case db.is_local_mode(db_state) {
    True -> {
      div([], [
        div([], [element.text("Local Development Mode")]),
        todo_list.view(todos, new_todo_name) |> element.map(map_todo_msg),
      ])
    }
    False -> {
      case db_state.auth_status {
        db.Loading -> {
          div([], [p([], [element.text("Loading...")])])
        }
        db.SigningOut -> {
          div([], [p([], [element.text("Signing out...")])])
        }
        db.NotAuthenticated | db.AuthenticationError(_) -> {
          div([], [p([], [element.text("Redirecting to login...")])])
        }
        db.Authenticated(db.RemoteAuth(_, user)) -> {
          div([], [
            div([], [element.text("Welcome, " <> user.email <> "!")]),
            div([], [
              button([on_click(SignOut)], [
                element.text("Sign out"),
              ]),
            ]),

            todo_list.view(todos, new_todo_name) |> element.map(map_todo_msg),
          ])
        }
        db.Authenticated(db.LocalAuth(_)) -> {
          div([], [
            div([], [element.text("Welcome, local user!")]),
            todo_list.view(todos, new_todo_name) |> element.map(map_todo_msg),
          ])
        }
      }
    }
  }
}

fn map_todo_msg(todo_msg: todo_list.Msg) -> Msg {
  case todo_msg {
    todo_list.UpdateNewTodoName(name) -> UpdateNewTodoName(name)
    todo_list.SubmitNewTodo -> SubmitNewTodo
    todo_list.ToggleTodoStatus(id) -> ToggleTodoStatus(id)
    todo_list.DeleteTodo(id) -> DeleteTodo(id)
  }
}
