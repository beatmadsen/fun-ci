# frozen_string_literal: true

require "prism"

# Finds calls a Ruby source must not make, by rule: bare method names (no
# receiver), methods on named constants, methods on any receiver, and
# backticks. Each offence reads "path:line calls name".
class CallScanner
  Rules = Data.define(:bare, :on_receiver, :any_receiver, :backticks)

  SPAWNING = Rules.new(bare: %i[spawn fork system exec], backticks: true, any_receiver: [],
                       on_receiver: { "Process" => %i[spawn fork exec kill], "Kernel" => %i[spawn fork system exec],
                                      "IO" => %i[popen], "Open3" => :all })
  NONDETERMINISTIC = Rules.new(bare: %i[sleep], backticks: false,
                               any_receiver: %i[instance_variable_get instance_variable_set],
                               on_receiver: { "Thread" => %i[pass], "Timeout" => %i[timeout], "Kernel" => %i[sleep] })

  def initialize(source, path, rules)
    @root = Prism.parse(source).value
    @path = path
    @rules = rules
  end

  def offences = visit(@root)

  private

  def visit(node)
    names(node).map { |name| "#{@path}:#{node.location.start_line} calls #{name}" } +
      node.compact_child_nodes.flat_map { |child| visit(child) }
  end

  def names(node)
    case node
    when Prism::XStringNode, Prism::InterpolatedXStringNode then @rules.backticks ? ["backticks"] : []
    when Prism::CallNode then call_names(node)
    else []
    end
  end

  def call_names(node)
    receiver = node.receiver&.slice
    return [node.name.to_s] if receiver.nil? && @rules.bare.include?(node.name)
    return ["#{receiver}.#{node.name}"] if on_receiver?(receiver, node.name)
    return [node.name.to_s] if receiver && @rules.any_receiver.include?(node.name)

    []
  end

  def on_receiver?(receiver, name)
    allowed = @rules.on_receiver.fetch(receiver, [])
    allowed == :all || allowed.include?(name)
  end
end
