# frozen_string_literal: true

# Boot file for the mutation lane (see .mutineer.yml): every constant a
# mutant can touch has to be loaded here, before mutineer forks per mutant.
# Coverage restarts first, counting calls of one-line methods, so their
# mutants are run rather than reported uncovered (support/endless_coverage).
require_relative "support/mutation_scope"
require_relative "support/endless_coverage"
EndlessCoverage.install
MutationScope.sources.each { |path| require File.join(MutationScope::ROOT, path) }
