# frozen_string_literal: true

# Boot file for the mutation lane (see .mutineer.yml): every constant a
# mutant can touch has to be loaded here, before mutineer forks per mutant.
require "fun_ci"
Dir[File.expand_path("../lib/fun_ci/{persistence,pipeline,setup}/*.rb", __dir__)].each { |file| require file }
require "fun_ci/cli"
