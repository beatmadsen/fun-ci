# frozen_string_literal: true

# What the mutation lane mutates: all of lib/. The Rakefile mutates these
# files and test/mutation_boot.rb loads them, so a mutant never reopens a
# constant the boot did not define.
module MutationScope
  ROOT = File.expand_path("../..", __dir__)

  def self.sources = Dir.glob("lib/**/*.rb", base: ROOT).sort
end
