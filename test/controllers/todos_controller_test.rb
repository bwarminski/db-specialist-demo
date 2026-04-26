# ABOUTME: Exercises the demo todo endpoints through Rails integration requests.
# ABOUTME: Verifies the HTML and JSON API surfaces needed by the benchmark app.
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

  test "api index paginates one user's open todos using created_desc order" do
    user = User.create!(name: "api index user")
    other_user = User.create!(name: "api index other user")
    oldest_open = Todo.create!(user: user, title: "oldest open todo", status: "open", created_at: 10.minutes.from_now, updated_at: 10.minutes.from_now)
    middle_open = Todo.create!(user: user, title: "middle open todo", status: "open", created_at: 20.minutes.from_now, updated_at: 20.minutes.from_now)
    newest_open = Todo.create!(user: user, title: "newest open todo", status: "open", created_at: 30.minutes.from_now, updated_at: 30.minutes.from_now)
    Todo.create!(user: user, title: "closed todo", status: "closed", created_at: Time.current, updated_at: Time.current)
    other_user_open = Todo.create!(user: other_user, title: "other user open todo", status: "open", created_at: 40.minutes.from_now, updated_at: 40.minutes.from_now)

    get "/api/todos", params: { user_id: user.id, status: "open", page: 2, per_page: 1 }

    assert_response :success
    body = JSON.parse(response.body)

    assert_equal [middle_open.id], body.fetch("items").map { |todo| todo.fetch("id") }
    assert_equal ["open"], body.fetch("items").map { |todo| todo.fetch("status") }.uniq
    refute_includes body.fetch("items").map { |todo| todo.fetch("id") }, newest_open.id
    refute_includes body.fetch("items").map { |todo| todo.fetch("id") }, oldest_open.id
    refute_includes body.fetch("items").map { |todo| todo.fetch("id") }, other_user_open.id
  end

  test "api index rejects unsupported order values" do
    get "/api/todos", params: { status: "open", page: 1, per_page: 1, order: "title_asc" }

    assert_response :bad_request
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
    assert_equal 1, JSON.parse(response.body).fetch("deleted_count")
    refute Todo.exists?(first_closed.id)
    assert Todo.exists?(second_closed.id)
    assert_equal "open", Todo.find_by!(title: "first open").status
  end

  test "api counts returns per-user totals while preserving count n plus one" do
    created_users = 4.times.map do |index|
      user = User.create!(name: "counts user #{index}")
      Todo.create!(user: user, title: "counts todo #{index}", status: index.even? ? "open" : "closed")
      user
    end

    count_query_events = capture_query_events do
      get "/api/todos/counts"
    end

    assert_response :success
    body = JSON.parse(response.body)

    created_users.each do |user|
      assert_equal 1, body.fetch(user.id.to_s)
    end

    per_user_count_queries = count_query_events.count do |event|
      event.fetch(:sql).match?(/COUNT\(\*\)/) && event.fetch(:sql).match?(/"todos"\."user_id"/)
    end

    assert_operator per_user_count_queries, :>=, created_users.length
  end

  test "api search filters matching todos to one user while preserving contains like query shape" do
    user = User.create!(name: "api search user")
    other_user = User.create!(name: "api search other user")
    matching_todo = Todo.create!(user: user, title: "alpha task", status: "open", created_at: 10.minutes.ago, updated_at: 10.minutes.ago)
    newer_matching_todo = Todo.create!(user: user, title: "task alpha beta", status: "closed", created_at: 5.minutes.ago, updated_at: 5.minutes.ago)
    Todo.create!(user: user, title: "gamma task", status: "open")
    other_user_match = Todo.create!(user: other_user, title: "alpha other user task", status: "open", created_at: 1.minute.ago, updated_at: 1.minute.ago)

    search_query_events = capture_query_events do
      get "/api/todos/search", params: { user_id: user.id, q: "alpha" }
    end

    assert_response :success
    body = JSON.parse(response.body)

    assert_equal [newer_matching_todo.id, matching_todo.id], body.fetch("items").map { |todo| todo.fetch("id") }
    assert_equal ["closed", "open"], body.fetch("items").map { |todo| todo.fetch("status") }.sort
    refute_includes body.fetch("items").map { |todo| todo.fetch("id") }, other_user_match.id
    assert search_query_events.any? { |event| contains_like_query?(event, "alpha") }
  end

  private

  def capture_query_events
    query_events = []
    callback = lambda do |_name, _started, _finished, _unique_id, payload|
      next if payload[:name] == "SCHEMA"
      next unless payload[:sql].start_with?("SELECT")

      query_events << {
        sql: payload[:sql],
        binds: payload.fetch(:binds).map { |bind| bind.value_for_database }
      }
    end

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      yield
    end

    query_events
  end

  def contains_like_query?(event, term)
    sql = event.fetch(:sql)
    binds = event.fetch(:binds)

    sql.match?(/title/i) &&
      sql.match?(/\bLIKE\b/i) &&
      (binds.include?("%#{term}%") || sql.include?("%#{term}%"))
  end
end
