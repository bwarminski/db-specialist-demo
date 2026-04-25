# ABOUTME: Verifies the benchmark seed script produces the expected mixed-workload dataset.
# ABOUTME: Confirms default seed sizing and env overrides through the real benchmark runner path.
require "json"
require "minitest/autorun"
require "open3"

class SeedsTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_seed_defaults_match_the_mixed_workload_distribution
    snapshot = seed_snapshot

    assert_equal 1_000, snapshot.fetch("users")
    assert_equal 100_000, snapshot.fetch("todos")
    assert_in_delta 0.6, snapshot.fetch("open_ratio"), 0.05
  end

  def test_seed_respects_row_fraction_and_seed_overrides
    first_snapshot = seed_snapshot("ROWS_PER_TABLE" => "200", "OPEN_FRACTION" => "0.25", "SEED" => "11")
    repeated_snapshot = seed_snapshot("ROWS_PER_TABLE" => "200", "OPEN_FRACTION" => "0.25", "SEED" => "11")
    different_snapshot = seed_snapshot("ROWS_PER_TABLE" => "200", "OPEN_FRACTION" => "0.25", "SEED" => "12")

    assert_equal 1_000, first_snapshot.fetch("users")
    assert_equal 200, first_snapshot.fetch("todos")
    assert_in_delta 0.25, first_snapshot.fetch("open_ratio"), 0.1
    assert_equal first_snapshot.fetch("first_statuses"), repeated_snapshot.fetch("first_statuses")
    refute_equal first_snapshot.fetch("first_statuses"), different_snapshot.fetch("first_statuses")
  end

  private

  def seed_snapshot(overrides = {})
    runner = <<~RUBY
      require "json"
      load Rails.root.join("db/schema.rb")
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

  def base_env
    {
      "SECRET_KEY_BASE" => "test"
    }
  end
end
