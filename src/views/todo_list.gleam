import gleam/list
import gleam/option.{None, Some}
import lib/todos.{type Todo, type TodoStatus}
import lustre/attribute.{class, placeholder, type_, value}
import lustre/element.{type Element, text}
import lustre/element/html.{button, div, form, h2, input, li, p, span, ul}
import lustre/event.{on_click, on_input, on_submit}
import optimist

pub type Msg {
  UpdateNewTodoName(String)
  SubmitNewTodo
  ToggleTodoStatus(String)
  DeleteTodo(String)
}

pub fn view(
  todos: optimist.Optimistic(List(Todo)),
  new_todo_name: String,
) -> Element(Msg) {
  div([class("todo-app")], [
    h2([], [text("My Todos")]),

    form([on_submit(fn(_) { SubmitNewTodo })], [
      input([
        type_("text"),
        placeholder("Add a new todo..."),
        value(new_todo_name),
        on_input(UpdateNewTodoName),
      ]),
      button([type_("submit")], [text("Add Todo")]),
    ]),

    case optimist.unwrap(todos) {
      [] -> p([], [text("No todos yet. Add one above!")])
      todo_list -> {
        ul([class("todo-list")], {
          list.map(todo_list, fn(item) {
            li([class("todo-item " <> status_class(item.status))], [
              span([class("todo-name")], [text(item.name)]),
              case item.deadline {
                Some(deadline) ->
                  span([class("todo-deadline")], [
                    text(" (Due: " <> deadline <> ")"),
                  ])
                None -> text("")
              },
              button(
                [
                  class("status-toggle"),
                  on_click(ToggleTodoStatus(item.id)),
                ],
                [text(status_button_text(item.status))],
              ),
              button(
                [
                  class("delete-btn"),
                  on_click(DeleteTodo(item.id)),
                ],
                [text("Delete")],
              ),
            ])
          })
        })
      }
    },
  ])
}

fn status_class(status: TodoStatus) -> String {
  case status {
    todos.Pending -> "pending"
    todos.InProgress -> "in-progress"
    todos.Completed -> "completed"
  }
}

fn status_button_text(status: TodoStatus) -> String {
  case status {
    todos.Pending -> "Start"
    todos.InProgress -> "Complete"
    todos.Completed -> "Reset"
  }
}
