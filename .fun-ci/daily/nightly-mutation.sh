#!/usr/bin/env ruby
# frozen_string_literal: true

# A daily job: how the latest finished run of the nightly mutation workflow
# (.github/workflows/mutation.yml) went, so its verdict reaches the console.
# It fails when that run failed, or when none finished in the last two days,
# since GitHub turns a schedule off in a repository that sees no activity
# for 60 days, and nothing else would say so.
require "json"
require "open3"
require "time"

STALE = 2 * 86_400
QUERY = %w[gh run list --workflow mutation.yml --status completed --limit 1 --json conclusion,createdAt,url].freeze

def latest
  out, err, status = Open3.capture3(*QUERY)
  abort "gh could not list the nightly mutation runs (is it logged in?): #{err.strip}" unless status.success?
  JSON.parse(out).first || abort("No nightly mutation run has finished yet")
rescue Errno::ENOENT
  abort "gh is not installed: https://cli.github.com"
end

run = latest
puts "The nightly mutation run of #{run["createdAt"]}: #{run["conclusion"]}", run["url"]
abort "It failed: the run says which lane, and which mutants survived" unless run["conclusion"] == "success"
abort "None finished in the last two days: is the schedule on? gh workflow view mutation.yml" if
  Time.now - Time.parse(run["createdAt"]) > STALE
