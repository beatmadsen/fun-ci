# frozen_string_literal: true

require "yaml"

# The recorded failing runs that pin each preset (architecture.md, "Evidence of a failed stage"), in
# test/fixtures/evidence/<preset>/: output.log, meta.yml, expected.yml and the recipe.yml it was recorded from.
module EvidenceFixtures
  ROOT = File.expand_path("../fixtures/evidence", __dir__)

  Fixture = Data.define(:name, :dir) do
    def output = File.binread(File.join(dir, "output.log"))
    def meta = YAML.safe_load_file(File.join(dir, "meta.yml"))
    def expected = YAML.safe_load_file(File.join(dir, "expected.yml"))
    def recipe = YAML.safe_load_file(File.join(dir, "recipe.yml"))

    # The names at the top of the recorded project, as `fun-ci init` sees them.
    def project_entries = recipe.fetch("files").keys.map { |path| path.split("/").first }.uniq
  end

  def self.all = Dir.children(ROOT).sort.map { |name| named(name) }
  def self.named(name) = Fixture.new(name: name, dir: File.join(ROOT, name))
end
