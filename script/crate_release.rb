# frozen_string_literal: true

require "json"
require "net/http"

# Publishes the renderer crate to crates.io, after the platform gems and
# before `rake release` tags the commit, so `cargo install fun-ci-renderer`
# gets the renderer the release's gems bundle. A version crates.io has
# already is left out: a release that leaves the renderer alone, or stopped
# part way, can be run again. Publishing needs `cargo login` beforehand.
module CrateRelease
  MANIFEST = File.expand_path("../renderer/Cargo.toml", __dir__)
  VERSIONS = URI("https://crates.io/api/v1/crates/fun-ci-renderer")
  CARGO_PUBLISH = ->(_version) { system("cargo", "publish", "--locked", "--manifest-path", MANIFEST, exception: true) }
  DRY_RUN = ->(version) { puts "Would publish fun-ci-renderer #{version}" }

  def self.version(manifest) = manifest[/^\[package\]\n(?:[^\[].*\n)*?version = "([^"]+)"/, 1]

  # body: what crates.io answers for the crate, its versions or an error.
  def self.published(body) = JSON.parse(body).fetch("versions", []).map { |version| version["num"] }

  def self.publisher(env) = env["DRY_RUN"] ? DRY_RUN : CARGO_PUBLISH

  # publisher: what publishes one version, CARGO_PUBLISH or DRY_RUN.
  def self.publish(version, published, publisher)
    publisher.call(version) unless published.include?(version)
  end

  def self.release(publisher) = publish(version(File.read(MANIFEST)), published(fetch), publisher)

  # crates.io refuses a request that doesn't say who sends it.
  def self.fetch
    Net::HTTP.get(VERSIONS, { "User-Agent" => "fun-ci release (https://github.com/beatmadsen/fun-ci)" })
  end
end
