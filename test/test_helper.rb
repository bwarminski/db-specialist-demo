# ABOUTME: Boots Rails test support for the demo application integration tests.
# ABOUTME: Loads schema-backed tables so request tests can create their own records.
ENV["RAILS_ENV"] ||= "test"

require_relative "../config/environment"
require "rails/test_help"

load Rails.root.join("db/schema.rb") unless ActiveRecord::Base.connection.data_source_exists?("users")

class ActiveSupport::TestCase
  parallelize(workers: 1)
end
