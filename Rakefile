# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"

Minitest::TestTask.create(:test) do |t|
  t.test_globs = ["test/**/test_*.rb"]
end

Minitest::TestTask.create(:integration) do |t|
  t.test_globs = ["test/integration/**/*_test.rb"]
end

require "rubocop/rake_task"

RuboCop::RakeTask.new

task default: %i[test rubocop]
