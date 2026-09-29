# frozen_string_literal: true

# Which mutation lanes the nightly workflow (.github/workflows/mutation.yml)
# runs: those fed by a file changed since its last finished run, or every lane
# when there is no such run in this clone's history. Prints them as step
# outputs.
#
#   ruby script/mutation_lanes.rb [LAST_SHA] >> "$GITHUB_OUTPUT"
module MutationLanes
  SHARED = ["Rakefile", ".github/workflows/mutation.yml"].freeze
  FEEDS = {
    "ruby" => ["lib/", "test/", "Gemfile", "Gemfile.lock", ".mutineer.yml", *SHARED],
    "rust" => ["renderer/", "contract/", "rust-toolchain.toml", *SHARED]
  }.freeze

  # changed: the paths changed since the last finished run, nil with none to compare with.
  def self.for(changed) = FEEDS.transform_values { |feeds| changed.nil? || changed.any? { |path| fed?(path, feeds) } }

  def self.fed?(path, feeds) = feeds.any? { |feed| feed.end_with?("/") ? path.start_with?(feed) : path == feed }

  def self.outputs(lanes) = lanes.map { |lane, runs| "#{lane}=#{runs}\n" }.join

  def self.changed_since(sha)
    return nil if sha.to_s.empty? || !system("git", "cat-file", "-e", "#{sha}^{commit}", err: File::NULL)

    IO.popen(["git", "diff", "--name-only", sha, "HEAD"], &:read).lines(chomp: true)
  end
end

print MutationLanes.outputs(MutationLanes.for(MutationLanes.changed_since(ARGV[0]))) if $PROGRAM_NAME == __FILE__
