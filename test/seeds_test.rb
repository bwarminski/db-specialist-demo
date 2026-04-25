# ABOUTME: Verifies the benchmark seed script produces the expected mixed-workload dataset.
# ABOUTME: Confirms default seed sizing and env overrides through the real benchmark runner path.
require "json"
require "minitest/autorun"
require "open3"

class SeedContractTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  SEEDS_PATH = File.join(ROOT, "db/seeds.rb")

  def test_seed_defaults_and_sql_shape_match_the_mixed_workload_contract
    seeds_source = seed_contract_source

    assert_includes seeds_source, 'ENV.fetch("ROWS_PER_TABLE", "100000")'
    assert_includes seeds_source, 'ENV.fetch("OPEN_FRACTION", "0.6")'
    assert_includes seeds_source, 'ENV.fetch("SEED", "42")'
    assert_includes seeds_source, "WHEN random() < \#{open_fraction} THEN 'open'"
    assert_includes seeds_source, "FROM generate_series(1, \#{rows_per_table}) AS i;"
  end

  private

  def seed_contract_source
    File.read(SEEDS_PATH)
  end
end

class SeedExecutionTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_seed_respects_row_fraction_and_seed_overrides_with_repeatable_output
    prepare_benchmark_database

    first_snapshot = run_seed_snapshot("ROWS_PER_TABLE" => "200", "OPEN_FRACTION" => "0.25", "SEED" => "11")
    repeated_snapshot = run_seed_snapshot("ROWS_PER_TABLE" => "200", "OPEN_FRACTION" => "0.25", "SEED" => "11")
    different_snapshot = run_seed_snapshot("ROWS_PER_TABLE" => "200", "OPEN_FRACTION" => "0.25", "SEED" => "12")

    assert_equal 1_000, first_snapshot.fetch("users")
    assert_equal 200, first_snapshot.fetch("todos")
    assert_in_delta 0.25, first_snapshot.fetch("open_ratio"), 0.1
    assert_equal first_snapshot.fetch("first_statuses"), repeated_snapshot.fetch("first_statuses")
    refute_equal first_snapshot.fetch("first_statuses"), different_snapshot.fetch("first_statuses")
  end

  private

  def run_seed_snapshot(overrides = {})
    runner = <<~RUBY
      require "json"
      load Rails.root.join("db/seeds.rb")
      puts JSON.generate(
        users: User.count,
        todos: Todo.count,
        open_ratio: Todo.where(status: "open").count.to_f / Todo.count,
        first_statuses: Todo.order(:id).limit(20).pluck(:status)
      )
    RUBY

    stdout, stderr, status = Open3.capture3(
      base_env.merge(overrides),
      "bundle",
      "exec",
      "rails",
      "runner",
      "-e",
      "benchmark",
      runner,
      chdir: ROOT
    )

    assert status.success?, "seed runner failed:\n#{stdout}\n#{stderr}"

    JSON.parse(stdout.lines.last)
  end

  def prepare_benchmark_database
    stdout, stderr, status = Open3.capture3(
      base_env,
      "bundle",
      "exec",
      "rails",
      "db:prepare",
      "RAILS_ENV=benchmark",
      chdir: ROOT
    )

    assert status.success?, "benchmark db prepare failed:\n#{stdout}\n#{stderr}"
  end

  def base_env
    {
      "SECRET_KEY_BASE" => "test"
    }
  end
end
