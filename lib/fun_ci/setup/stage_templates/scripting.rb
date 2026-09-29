# frozen_string_literal: true

require_relative "shell"

module FunCi
  module Setup
    # Interpreted stacks: Ruby, Python, PHP and Perl.
    module StageTemplates
      def self.python(runner, build)
        stages("#{runner}ruff check .", build, "#{runner}pytest -m \"not slow\"", "#{runner}pytest -m slow")
      end

      SCRIPTING = {
        ruby_rspec: stages("bundle exec rubocop", "bundle install --quiet",
                           "bundle exec rspec --tag ~slow", "bundle exec rspec --tag slow"),
        ruby_bundler: stages("bundle exec rubocop", "bundle install --quiet",
                             "bundle exec rake test", "bundle exec rake test:slow"),
        php_composer: stages("vendor/bin/phpcs", "composer install --no-interaction --no-progress",
                             "vendor/bin/phpunit --exclude-group slow", "vendor/bin/phpunit --group slow"),
        python_uv: python("uv run ", "uv sync"),
        python_poetry: python("poetry run ", "poetry install"),
        python: python("python3 -m ", "python3 -m compileall -q ."),
        perl: stages("perlcritic lib", "cpanm --installdeps --notest .", "prove -lr t", "prove -lr xt")
      }.freeze
    end
  end
end
