# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "rake"
gem "rubocop", "~> 1.60", require: false
# parallel 2 (a RuboCop dependency) needs Ruby 3.3, and the gate still runs
# on 3.2 (.github/workflows/ci.yml).
gem "parallel", "< 2", require: false

# Mutineer needs Ruby 3.4. install_if keeps it in the lockfile on every Ruby,
# so a frozen bundle (as CI installs it) accepts the same lockfile on 3.2 and
# 3.3, where the mutation lane is simply not installed.
install_if -> { RUBY_VERSION >= "3.4" } do
  gem "mutineer", "~> 1.0", require: false
end

group :test do
  gem "activesupport", "~> 8.1"
  gem "logger" # required explicitly since Ruby 4.0
  gem "minitest"
end
