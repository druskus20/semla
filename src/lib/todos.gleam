import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/option.{type Option, None, Some}
import lib/db.{type DbState}
import lustre/effect.{type Effect}
import supa/database

pub type TodoStatus {
  Pending
  InProgress
  Completed
}

pub type Todo {
  Todo(
    id: String,
    name: String,
    deadline: Option(String),
    status: TodoStatus,
    user_id: String,
  )
}

fn get_access_token(db_state: DbState) -> Result(String, String) {
  db.get_access_token(db_state)
}

fn status_to_string(status: TodoStatus) -> String {
  case status {
    Pending -> "pending"
    InProgress -> "in_progress"
    Completed -> "completed"
  }
}

fn string_to_status(str: String) -> TodoStatus {
  case str {
    "pending" -> Pending
    "in_progress" -> InProgress
    "completed" -> Completed
    _ -> Pending
  }
}

pub fn list_todos(db_state: DbState) -> Effect(Result(List(Todo), String)) {
  case db.is_local_mode(db_state) {
    True -> {
      effect.from(fn(dispatch) { dispatch(Ok([])) })
    }
    False -> {
      let client = db.get_client(db_state)
      case db.get_user_id(db_state), get_access_token(db_state) {
        Ok(user_id), Ok(access_token) -> {
          let query =
            database.from("todos")
            |> database.filter(database.eq("user_id", user_id))

          database.execute_select(
            client,
            Some(access_token),
            query,
            todo_decoder(),
            fn(result) {
              case result {
                Ok(todos) -> Ok(todos)
                Error(_) -> Error("Failed to fetch todos")
              }
            },
          )
        }
        Error(msg), _ -> {
          effect.from(fn(dispatch) { dispatch(Error(msg)) })
        }
        _, Error(msg) -> {
          effect.from(fn(dispatch) { dispatch(Error(msg)) })
        }
      }
    }
  }
}

pub fn create_todo(
  db_state: DbState,
  name: String,
  deadline: Option(String),
  status: TodoStatus,
) -> Effect(Result(Todo, String)) {
  case db.is_local_mode(db_state) {
    True -> {
      let id = int.random(999_999_999_999_999) |> int.to_string()

      let new_todo =
        Todo(
          id: "local-" <> id,
          name: name,
          deadline: deadline,
          status: status,
          user_id: "local",
        )
      effect.from(fn(dispatch) { dispatch(Ok(new_todo)) })
    }
    False -> {
      let client = db.get_client(db_state)
      case db.get_user_id(db_state), get_access_token(db_state) {
        Ok(user_id), Ok(access_token) -> {
          let data_fields = [
            #("name", json.string(name)),
            #("status", json.string(status_to_string(status))),
            #("user_id", json.string(user_id)),
          ]

          let data_fields = case deadline {
            Some(d) -> [#("deadline", json.string(d)), ..data_fields]
            None -> data_fields
          }

          let data = json.object(data_fields)

          database.execute_insert(
            client,
            Some(access_token),
            "todos",
            data,
            fn(result) {
              case result {
                Ok([dynamic_todo]) -> {
                  case decode.run(dynamic_todo, todo_decoder()) {
                    Ok(new_todo) -> Ok(new_todo)
                    Error(_) -> Error("Failed to parse created todo")
                  }
                }
                Ok(_) -> Error("Unexpected response from create")
                Error(_) -> Error("Failed to create todo")
              }
            },
          )
        }
        Error(msg), _ -> {
          effect.from(fn(dispatch) { dispatch(Error(msg)) })
        }
        _, Error(msg) -> {
          effect.from(fn(dispatch) { dispatch(Error(msg)) })
        }
      }
    }
  }
}

pub fn update_todo(
  db_state: DbState,
  id: String,
  name: String,
  deadline: Option(String),
  status: TodoStatus,
) -> Effect(Result(Todo, String)) {
  case db.is_local_mode(db_state) {
    True -> {
      let updated_todo =
        Todo(
          id: id,
          name: name,
          deadline: deadline,
          status: status,
          user_id: "local",
        )
      effect.from(fn(dispatch) { dispatch(Ok(updated_todo)) })
    }
    False -> {
      let client = db.get_client(db_state)
      case db.get_user_id(db_state), get_access_token(db_state) {
        Ok(user_id), Ok(access_token) -> {
          let data_fields = [
            #("name", json.string(name)),
            #("status", json.string(status_to_string(status))),
          ]

          let data_fields = case deadline {
            Some(d) -> [#("deadline", json.string(d)), ..data_fields]
            None -> [#("deadline", json.null()), ..data_fields]
          }

          let data = json.object(data_fields)

          let query =
            database.from("todos")
            |> database.filter(database.eq("id", id))
            |> database.filter(database.eq("user_id", user_id))

          database.execute_update(
            client,
            Some(access_token),
            query,
            data,
            fn(result) {
              case result {
                Ok([dynamic_todo]) -> {
                  case decode.run(dynamic_todo, todo_decoder()) {
                    Ok(updated_todo) -> Ok(updated_todo)
                    Error(_) -> Error("Failed to parse updated todo")
                  }
                }
                Ok([]) -> Error("Todo not found for update")
                Ok(_) -> Error("Multiple todos returned from update")
                Error(_) -> Error("Failed to update todo")
              }
            },
          )
        }
        Error(msg), _ -> {
          effect.from(fn(dispatch) { dispatch(Error(msg)) })
        }
        _, Error(msg) -> {
          effect.from(fn(dispatch) { dispatch(Error(msg)) })
        }
      }
    }
  }
}

pub fn delete_todo(db_state: DbState, id: String) -> Effect(Result(Nil, String)) {
  case db.is_local_mode(db_state) {
    True -> {
      effect.from(fn(dispatch) { dispatch(Ok(Nil)) })
    }
    False -> {
      let client = db.get_client(db_state)
      case db.get_user_id(db_state), get_access_token(db_state) {
        Ok(user_id), Ok(access_token) -> {
          let query =
            database.from("todos")
            |> database.filter(database.eq("id", id))
            |> database.filter(database.eq("user_id", user_id))

          database.execute_delete(client, Some(access_token), query, fn(result) {
            case result {
              Ok(_) -> Ok(Nil)
              Error(_) -> Error("Failed to delete todo")
            }
          })
        }

        Error(msg), _ -> {
          effect.from(fn(dispatch) { dispatch(Error(msg)) })
        }
        _, Error(msg) -> {
          effect.from(fn(dispatch) { dispatch(Error(msg)) })
        }
      }
    }
  }
}

fn todo_decoder() -> decode.Decoder(Todo) {
  use id <- decode.field("id", decode.string)
  use name <- decode.field("name", decode.string)
  use deadline <- decode.field("deadline", decode.optional(decode.string))
  use status_str <- decode.field("status", decode.string)
  use user_id <- decode.field("user_id", decode.string)

  decode.success(Todo(
    id: id,
    name: name,
    deadline: deadline,
    status: string_to_status(status_str),
    user_id: user_id,
  ))
}
