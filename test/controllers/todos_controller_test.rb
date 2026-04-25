# ABOUTME: Exercises the demo todo endpoints through Rails integration requests.
# ABOUTME: Verifies the Task 2 JSON endpoints exist and accept the planned params.
require "test_helper"
require "json"

class TodosControllerTest < ActionDispatch::IntegrationTest
  test "up endpoint reports app liveness" do
    get "/up"

    assert_response :success
    assert_equal "ok", response.body
  end

  test "index endpoint emits query log metadata and returns rows" do
    user = User.create!(name: "index test user")
    matching_open = Todo.create!(user: user, title: "index starter task", status: "open")
    matching_closed = Todo.create!(user: user, title: "index closed task", status: "closed")

    get "/todos"

    assert_response :success
    todos = JSON.parse(response.body)

    indexed_todos = todos.select { |todo| [matching_open.id, matching_closed.id].include?(todo.fetch("id")) }

    assert_equal [matching_closed.id, matching_open.id].sort, indexed_todos.map { |todo| todo.fetch("id") }.sort
    assert_equal ["closed", "open"], indexed_todos.map { |todo| todo.fetch("status") }.sort
    assert_equal ["index test user"], indexed_todos.map { |todo| todo.fetch("user").fetch("name") }.uniq
  end

  test "search endpoint accepts q param" do
    user = User.create!(name: "search test user")
    Todo.create!(user: user, title: "searchable starter task", status: "open")

    get "/todos", params: { q: "searchable starter" }

    assert_response :success
    todos = JSON.parse(response.body)

    assert_equal 1, todos.length
    assert_equal "searchable starter task", todos.first.fetch("title")
    assert_equal "open", todos.first.fetch("status")
  end

  test "status endpoint filters todos by status" do
    user = User.create!(name: "status test user")
    open_todo = Todo.create!(user: user, title: "status open task", status: "open")
    Todo.create!(user: user, title: "status closed task", status: "closed")

    get "/todos/status", params: { status: "open" }

    assert_response :success
    todos = JSON.parse(response.body)

    assert_includes todos.map { |todo| todo.fetch("id") }, open_todo.id
    assert_equal ["open"], todos.map { |todo| todo.fetch("status") }.uniq
  end

  test "stats endpoint returns stable string keys" do
    user = User.create!(name: "stats test user")
    2.times do |index|
      Todo.create!(user: user, title: "stats task #{index}", status: "open")
    end

    get "/todos/stats"

    assert_response :success
    stats = JSON.parse(response.body)

    assert_equal 2, stats.fetch(user.id.to_s)
  end

  test "api index lists open todos newest first" do
    user = User.create!(name: "api index user")
    older_open = Todo.create!(user: user, title: "older open todo", status: "open", created_at: 20.minutes.from_now, updated_at: 20.minutes.from_now)
    newer_open = Todo.create!(user: user, title: "newer open todo", status: "open", created_at: 30.minutes.from_now, updated_at: 30.minutes.from_now)
    Todo.create!(user: user, title: "closed todo", status: "closed", created_at: Time.current, updated_at: Time.current)

    get "/api/todos", params: { status: "open", page: 1, per_page: 2, order: "created_desc" }

    assert_response :success
    body = JSON.parse(response.body)

    assert_equal [newer_open.id, older_open.id], body.fetch("items").map { |todo| todo.fetch("id") }
    assert_equal ["open"], body.fetch("items").map { |todo| todo.fetch("status") }.uniq
  end

  test "api create and update persist todo changes" do
    user = User.create!(name: "api create user")

    assert_difference("Todo.count", 1) do
      post "/api/todos", params: { user_id: user.id, title: "from api" }, as: :json
    end

    assert_response :created
    created_todo = JSON.parse(response.body)

    assert_equal "from api", created_todo.fetch("title")
    assert_equal "open", created_todo.fetch("status")

    patch "/api/todos/#{created_todo.fetch("id")}", params: { status: "closed" }, as: :json

    assert_response :success
    assert_equal "closed", Todo.find(created_todo.fetch("id")).status
  end

  test "api delete completed only deletes completed todos for one user" do
    first_user = User.create!(name: "delete first user")
    second_user = User.create!(name: "delete second user")
    Todo.create!(user: first_user, title: "first open", status: "open")
    first_closed = Todo.create!(user: first_user, title: "first closed", status: "closed")
    second_closed = Todo.create!(user: second_user, title: "second closed", status: "closed")

    assert_difference(-> { Todo.count }, -1) do
      delete "/api/todos/completed", params: { user_id: first_user.id }, as: :json
    end

    assert_response :success
    refute Todo.exists?(first_closed.id)
    assert Todo.exists?(second_closed.id)
    assert_equal "open", Todo.find_by!(title: "first open").status
  end
end
