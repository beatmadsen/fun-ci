# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/trigger_test_kit"
require "fun_ci/persistence/database"
require "fun_ci/persistence/pipeline_recorder"
require "fun_ci/persistence/trunk_checks"

# A trigger given no trunk checks against the project's own
# (architecture.md, Checking against the trunk): in a directory that is no
# repository, that is none to be found, and it says so.
class TestTriggerDefaultTrunk < Minitest::Test
  include FunCiTestProject
  include TriggerTestKit

  def setup
    @dir = Dir.mktmpdir("fun-ci-default-trunk")
    @db = FunCi::Persistence::Database.connection(File.join(@dir, "db.sqlite3"))
    FunCi::Persistence::Database.migrate!(@db)
  end

  def teardown
    @db.close
    FileUtils.rm_rf(@dir)
  end

  def test_should_check_against_the_project_s_own_trunk_when_given_none
    project = in_project do |dir|
      build_trigger(dir, trunk: nil, recorder: FunCi::Persistence::DbRecorder.new(@db)).run
      dir
    end

    assert_equal "no trunk found; set trunk: in .fun-ci/config",
                 FunCi::Persistence::TrunkChecks.new(@db, project).latest("abc1234").merge.reason
  end
end
