# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../support/db_recorder_setup"
require "fun_ci/evidence/document"
require "json"

# The recorder keeps a failed stage's evidence as one document, and still
# fills the columns an older fun-ci on the same machine reads (why.md,
# "Storage and retention").
class TestPipelineRecorderEvidence < Minitest::Test
  include DbRecorderTestSetup

  FAILURE = { file: "a.rb", line: 3, test: "t", message: "m" }.freeze
  DOCUMENT = FunCi::Evidence::Document.legacy(tail: "one\ntwo\n", failures: [FAILURE])

  def setup
    super
    create_run
    @job_id = @recorder.start_stage("fast")
    @recorder.keep_evidence(@job_id, DOCUMENT)
  end

  def test_should_keep_the_evidence_as_json
    assert_equal JSON.parse(JSON.generate(DOCUMENT.to_h)), JSON.parse(job(@job_id)[:evidence])
  end

  def test_should_keep_the_output_s_last_lines_where_an_older_fun_ci_reads_them
    assert_equal "one\ntwo\n", job(@job_id)[:output_tail]
  end

  def test_should_keep_the_reported_failures_where_an_older_fun_ci_reads_them
    assert_equal [{ "file" => "a.rb", "line" => 3, "test" => "t", "message" => "m" }],
                 JSON.parse(job(@job_id)[:failures])
  end

  def test_should_keep_no_failures_where_an_older_fun_ci_reads_them_when_none_were_reported
    job_id = @recorder.start_stage("slow")
    @recorder.keep_evidence(job_id, FunCi::Evidence::Document.legacy(tail: "x\n", failures: []))

    assert_nil job(job_id)[:failures]
  end
end
