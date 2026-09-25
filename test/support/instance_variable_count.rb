# frozen_string_literal: true

require "prism"

# Counts the distinct instance variables each class or module in a Ruby
# source assigns, not counting those of classes nested inside it.
class InstanceVariableCount
  WRITES = [Prism::InstanceVariableWriteNode, Prism::InstanceVariableOrWriteNode, Prism::InstanceVariableAndWriteNode,
            Prism::InstanceVariableOperatorWriteNode, Prism::InstanceVariableTargetNode].freeze
  SCOPES = [Prism::ClassNode, Prism::ModuleNode].freeze

  def initialize(source)
    @root = Prism.parse(source).value
  end

  # { "ClassName" => [:@a, :@b] }
  def by_scope
    scopes(@root).to_h { |scope| [scope.constant_path.slice, assigned(scope.body)] }
  end

  private

  def scopes(node)
    own = SCOPES.any? { |type| node.is_a?(type) } ? [node] : []
    own + node.compact_child_nodes.flat_map { |child| scopes(child) }
  end

  def assigned(node)
    return [] if node.nil? || SCOPES.any? { |type| node.is_a?(type) }

    own = WRITES.any? { |type| node.is_a?(type) } ? [node.name] : []
    (own + node.compact_child_nodes.flat_map { |child| assigned(child) }).uniq
  end
end
