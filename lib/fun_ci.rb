# frozen_string_literal: true

require_relative "fun_ci/database"
require_relative "fun_ci/state_machine"
require_relative "fun_ci/pipeline_run"
require_relative "fun_ci/stage_job"
require_relative "fun_ci/project_config"

module FunCi
  VERSION = "0.0.1"

  BUILD_TIMEOUT = 30
  FAST_SUITE_TIMEOUT = 10
  SLOW_SUITE_TIMEOUT = 300
end
