# frozen_string_literal: true

# The git a project answers agent commands from, without running git: commits
# by SHA with their subjects, HEAD, and the project's top directory.
class FakeGit
  attr_reader :toplevel

  def branch = "main"

  def initialize(toplevel)
    @toplevel = toplevel
    @subjects = {}
    @head = nil
  end

  def commit(sha, subject)
    @subjects[sha] = subject
    @head = sha
  end

  def resolve(rev)
    return @head if rev == "HEAD"

    @subjects.keys.find { |sha| sha.start_with?(rev) }
  end

  def subject(sha) = @subjects.fetch(sha, "")
end
