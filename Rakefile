# frozen_string_literal: true

# Tiny Rakefile so `bundle exec rake test` feels at home. 🏠
require "rake/testtask"

Rake::TestTask.new do |t|
  t.libs << "test"
  t.pattern = "test/**/*_test.rb"
end

task default: :test
