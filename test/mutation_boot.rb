# frozen_string_literal: true

# Boot file for the mutation lane (see .mutineer.yml): every constant a
# mutant can touch has to be loaded here, before mutineer forks per mutant.
require_relative "support/mutation_scope"
MutationScope.sources.each { |path| require File.join(MutationScope::ROOT, path) }
