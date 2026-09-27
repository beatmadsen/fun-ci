# frozen_string_literal: true

module FunCi
  module Evidence
    # What a watched file looked like: a file counts as changed if any of
    # the three differ, since some file systems keep whole seconds, and
    # `cp -p` or a build cache can put an old time back (architecture.md, "Evidence of a failed stage").
    Stamp = Data.define(:size, :mtime, :inode)
  end
end
