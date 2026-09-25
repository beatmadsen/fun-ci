# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "rake"
gem "rubocop", "~> 1.60", require: false

# Mutineer needs Ruby 3.4. The gem supports 3.2, so on an older Ruby the
# mutation lane is simply not installed.
gem "mutineer", "~> 1.0", require: false if RUBY_VERSION >= "3.4"

group :test do
  gem "activesupport", "~> 8.1"
  gem "cucumber", "~> 9.0"
  gem "logger" # required explicitly since Ruby 4.0
  gem "minitest"
end
