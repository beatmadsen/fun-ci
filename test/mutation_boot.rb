# frozen_string_literal: true

# Boot file for the mutation lane (see .mutineer.yml): every constant a
# mutant can touch has to be loaded here, before mutineer forks per mutant.
# Coverage restarts first, counting every line a statement spans, so the
# mutants on them are run rather than reported uncovered
# (support/statement_coverage). What finished runs left running is stopped
# here, once, rather than by each process the lane forks.
require_relative "support/mutation_scope"
require_relative "support/statement_coverage"
require_relative "support/confinement_guard"
ConfinementGuard.remove_roots_of_finished_runs
StatementCoverage.install
MutationScope.sources.each { |path| require File.join(MutationScope::ROOT, path) }
