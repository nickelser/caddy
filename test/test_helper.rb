$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)

if ENV["CODECLIMATE_REPO_TOKEN"]
  require "codeclimate-test-reporter"
  CodeClimate::TestReporter.start
end

require "minitest/autorun"
require "caddy"

ENV["RACK_ENV"] = ENV["RAILS_ENV"] = "test"

$test_logger = begin
  l = Logger.new(STDOUT)
  l.level = Logger::ERROR
  l
end

Caddy.logger = $test_logger
