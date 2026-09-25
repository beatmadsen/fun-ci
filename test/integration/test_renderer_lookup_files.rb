# frozen_string_literal: true

require_relative "../test_helper"
require "fun_ci/console/renderer_lookup"
require "tmpdir"

# What counts as a renderer on disk: a file this user may run.
class TestRendererLookupFiles < Minitest::Test
  def setup = @dir = Dir.mktmpdir
  def teardown = FileUtils.rm_rf(@dir)

  def file(mode)
    File.join(@dir, "fun-ci-renderer").tap do |path|
      File.write(path, "#!/bin/sh\n")
      File.chmod(mode, path)
    end
  end

  def test_should_count_an_executable_file
    assert FunCi::Console::RendererLookup.runnable?(file(0o755))
  end

  def test_should_not_count_a_file_that_may_not_be_run
    refute FunCi::Console::RendererLookup.runnable?(file(0o644))
  end

  def test_should_not_count_a_directory
    refute FunCi::Console::RendererLookup.runnable?(@dir)
  end
end
