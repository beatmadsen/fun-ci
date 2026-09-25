# frozen_string_literal: true

# What the mutation lane mutates: lib/ except tui/ and animations/, which §5
# of the 2.0 plan deletes once the Rust renderer takes over. The Rakefile
# mutates these files and test/mutation_boot.rb loads them, so a mutant never
# reopens a constant the boot did not define.
module MutationScope
  ROOT = File.expand_path("../..", __dir__)
  LEFT_OUT = %r{\Alib/fun_ci/(tui|animations)/}

  def self.sources
    Dir.glob("lib/**/*.rb", base: ROOT).grep_v(LEFT_OUT).sort
  end
end
