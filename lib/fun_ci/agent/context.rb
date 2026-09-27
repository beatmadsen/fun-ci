# frozen_string_literal: true

module FunCi
  module Agent
    # What every agent command answers from: the database, the project's git,
    # and where to print.
    Context = Data.define(:db, :git, :io)
  end
end
