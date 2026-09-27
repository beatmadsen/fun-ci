# frozen_string_literal: true

module FunCi
  module Agent
    # What every agent command answers from: the database, the project's git,
    # where to print, and the time now (a callable).
    Context = Data.define(:db, :git, :io, :clock)
  end
end
