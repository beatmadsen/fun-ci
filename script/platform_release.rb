# frozen_string_literal: true

require "fileutils"
require "json"
require "net/http"
require "yaml"

# Pushes the platform gems the Gems workflow built for a commit
# (.github/workflows/gems.yml), before `rake release` tags it and pushes the
# plain gem, so nobody installing in between gets the gem without its
# renderer. Each push asks for an MFA code; a gem rubygems.org has already is
# left out, so a release that stopped part way can be run again.
module PlatformRelease
  class NotReady < StandardError; end

  WORKFLOW = File.expand_path("../.github/workflows/gems.yml", __dir__)
  VERSIONS = URI("https://rubygems.org/api/v1/versions/fun_ci.json")
  GEM_PUSH = ->(file) { system("gem", "push", file, exception: true) }
  DRY_RUN = ->(file) { puts "Would push #{file}" }

  def self.platforms(workflow)
    YAML.safe_load(workflow).dig("jobs", "platform", "strategy", "matrix", "include").map { |build| build["platform"] }
  end

  def self.missing(files, version, platforms)
    platforms.map { |platform| "fun_ci-#{version}-#{platform}.gem" } - files.map { |file| File.basename(file) }
  end

  def self.run_id(runs)
    run = runs.find { |candidate| candidate["conclusion"] == "success" }
    run ? run["databaseId"] : raise(NotReady, "no successful Gems run for this commit: push it and wait for CI")
  end

  # published: the versions rubygems.org lists, each { "number", "platform" }.
  def self.unpublished(files, published)
    names = published.map { |gem| ["fun_ci", gem["number"], gem["platform"]].reject { _1 == "ruby" }.join("-") }
    files.reject { |file| names.include?(File.basename(file, ".gem")) }
  end

  def self.pusher(env) = env["DRY_RUN"] ? DRY_RUN : GEM_PUSH

  # pusher: what pushes one gem, GEM_PUSH or DRY_RUN.
  def self.push(version, sha, pusher)
    files = Dir.glob(File.join(download(sha), "**", "*.gem"))
    lacking = missing(files, version, platforms(File.read(WORKFLOW)))
    raise NotReady, "the Gems workflow built no #{lacking.join(", ")}" if lacking.any?

    publish(files, published, pusher)
  end

  def self.publish(files, published, pusher) = unpublished(files, published).each { |file| pusher.call(file) }

  def self.download(sha)
    runs = JSON.parse(IO.popen(["gh", "run", "list", "--workflow", "gems.yml", "--commit", sha,
                                "--json", "databaseId,conclusion"], &:read))
    File.join("pkg", "platform-gems", sha).tap do |dir|
      FileUtils.rm_rf(dir)
      system("gh", "run", "download", run_id(runs).to_s, "--dir", dir, exception: true)
    end
  end

  def self.published
    JSON.parse(Net::HTTP.get(VERSIONS))
  rescue JSON::ParserError
    []
  end
end
