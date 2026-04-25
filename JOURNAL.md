# Journal

- 2026-04-24: Task 3 on `wip/mixed-todo-api` adds only the Todo JSON API surface and tests. Preserve the intentionally broken schema assumptions from `db/schema.rb`; do not add a status index or widen scope into count/search routes.
- 2026-04-24: Task 5 seed retune uses a standalone `test/seeds_test.rb` Minitest shelling into `rails runner -e benchmark` because `rails test` still forces the SQLite `test` environment and dies on the Postgres-only seed SQL.
- 2026-04-24: Running `SECRET_KEY_BASE=test RAILS_ENV=benchmark bundle exec ruby -Itest test/controllers/todos_controller_test.rb` hung with Postgres showing an `idle in transaction` backend, so keep that verification path separate from the focused seed check until the benchmark test harness is cleaned up.
