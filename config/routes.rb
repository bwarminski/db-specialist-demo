# ABOUTME: Declares the HTTP routes for the demo todo anti-pattern endpoints.
# ABOUTME: Maps the task routes directly to the controller actions under test.
Rails.application.routes.draw do
  get "/up", to: proc { [200, { "Content-Type" => "text/plain" }, ["ok"]] }
  get "/todos", to: "todos#index"
  get "/todos/status", to: "todos#status"
  get "/todos/stats", to: "todos#stats"

  scope "/api" do
    get "/todos", to: "todos#api_index"
    get "/todos/counts", to: "todos#counts"
    get "/todos/search", to: "todos#search"
    post "/todos", to: "todos#create"
    patch "/todos/:id", to: "todos#update"
    delete "/todos/completed", to: "todos#completed"
  end
end
