# frozen_string_literal: true

require_relative "fun_ci/persistence/database"
require_relative "fun_ci/persistence/state_machine"
require_relative "fun_ci/persistence/pipeline_run"
require_relative "fun_ci/persistence/stage_job"
require_relative "fun_ci/setup/project_config"

module FunCi
  VERSION = "1.2.0"

  BUILD_TIMEOUT = 30
  FAST_SUITE_TIMEOUT = 10
  SLOW_SUITE_TIMEOUT = 300
end
