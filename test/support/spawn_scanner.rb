# frozen_string_literal: true

require "prism"

# Finds the places a Ruby source starts a process: spawn, fork, system,
# exec, backticks and %x, Open3, IO.popen, and their Process/Kernel forms.
class SpawnScanner
  BARE = %i[spawn fork system exec].freeze
  ON_RECEIVER = { "Process" => %i[spawn fork exec], "Kernel" => BARE, "IO" => %i[popen] }.freeze

  def initialize(source, path)
    @source = source
    @path = path
  end

  def offences
    calls = []
    visit(Prism.parse(@source).value) { |node, name| calls << "#{@path}:#{node.location.start_line} calls #{name}" }
    calls
  end

  private

  def visit(node, &report)
    spawn_names(node).each { |name| report.call(node, name) }
    node.compact_child_nodes.each { |child| visit(child, &report) }
  end

  def spawn_names(node)
    case node
    when Prism::XStringNode, Prism::InterpolatedXStringNode then ["backticks"]
    when Prism::CallNode then call_names(node)
    else []
    end
  end

  def call_names(node)
    receiver = node.receiver&.slice
    return [node.name.to_s] if receiver.nil? && BARE.include?(node.name)
    return ["#{receiver}.#{node.name}"] if receiver == "Open3" || ON_RECEIVER.fetch(receiver, []).include?(node.name)

    []
  end
end
