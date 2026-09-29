# frozen_string_literal: true

module FunCi
  # Whether target/debug/fun-ci-renderer was built from renderer/src. `cargo
  # package` and `cargo publish` verify the crate in the same target
  # directory, and can leave the binary built from their packaged copy,
  # which cargo then counts as fresh however renderer/src changes; the lanes
  # that run the binary would then test old code.
  module RendererBuild
    # The command that cleans the binary when it was built from elsewhere
    # than renderer/src, so the next build is; nil when it needs none.
    def self.clean_command(manifest)
      renderer_dir = File.dirname(manifest)
      dep_info = File.join(renderer_dir, "target", "debug", "fun-ci-renderer.d")
      return nil unless stale?(File.exist?(dep_info) ? File.read(dep_info) : nil, File.join(renderer_dir, "src"))

      warn "fun-ci-renderer was built from a packaged copy of the crate, not renderer/src; cleaning it"
      ["cargo", "clean", "--manifest-path", manifest, "-p", "fun-ci-renderer"]
    end

    # dep_info: the binary's .d file (nil when it was never built).
    def self.stale?(dep_info, src_dir)
      return false unless dep_info

      sources = dep_info.split(":", 2).last.split
      sources.any? { |source| source.end_with?(".rs") && !source.start_with?("#{src_dir}/") }
    end
  end
end
