# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../../contract/capture/golden_corpus"
require "tmpdir"

class TestGoldenCorpusFiles < Minitest::Test
  def setup
    @root = Dir.mktmpdir("golden")
    @corpus = FunCi::Contract::GoldenCorpus.new(root: @root)
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  def test_scenario_names_are_the_jsonl_files_in_scenarios
    write_scenario("b-two", "")
    write_scenario("a-one", "")

    assert_equal %w[a-one b-two], @corpus.scenario_names
  end

  def test_messages_are_the_scenario_lines_parsed_as_json
    write_scenario("s", %({"t":"resize","cols":60,"rows":20}\n{"t":"tick","ms":100}\n))

    assert_equal %w[resize tick], @corpus.messages("s").map { |m| m["t"] }
  end

  def test_written_frames_read_back_byte_for_byte_in_order
    frames = ["\e[2J⠇".b, "second".b, "third".b]
    @corpus.write("s", frames)

    assert_equal frames, @corpus.golden("s")
  end

  def test_frames_are_numbered_with_four_digits_from_one
    @corpus.write("s", %w[a b])

    assert_equal %w[0001.bytes 0002.bytes], Dir.children(File.join(@root, "golden", "s")).sort
  end

  def test_rewriting_a_shorter_capture_leaves_no_stale_frames
    @corpus.write("s", %w[a b c])
    @corpus.write("s", %w[a])

    assert_equal ["a"], @corpus.golden("s")
  end

  private

  def write_scenario(name, content)
    FileUtils.mkdir_p(File.join(@root, "scenarios"))
    File.write(File.join(@root, "scenarios", "#{name}.jsonl"), content)
  end
end
