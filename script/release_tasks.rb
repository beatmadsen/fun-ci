# frozen_string_literal: true

# The release tasks, which the Rakefile loads.
namespace :release do
  desc "Push the platform gems the Gems workflow built for HEAD; each asks for an MFA code (DRY_RUN=1 only lists them)"
  task(:platform_gems) do
    require_relative "platform_release"
    require_relative "../lib/fun_ci/version"
    PlatformRelease.push(FunCi::VERSION, `git rev-parse HEAD`.strip, PlatformRelease.pusher(ENV))
  end

  desc "Publish the renderer crate to crates.io unless it has that version; needs cargo login (DRY_RUN=1 only says so)"
  task(:crate) do
    require_relative "crate_release"
    CrateRelease.release(CrateRelease.publisher(ENV))
  end
end

# `rake release` (bundler/gem_tasks) tags the commit, then pushes the plain
# gem; the platform gems go first, so nobody gets the gem without its renderer,
# then the crate, so `cargo install` gets the renderer they bundle.
if Rake::Task.task_defined?("release:source_control_push")
  Rake::Task["release:source_control_push"].enhance(["release:platform_gems", "release:crate"])
end
