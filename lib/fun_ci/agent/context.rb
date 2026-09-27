# frozen_string_literal: true

module FunCi
  module Agent
    # What every agent command answers from: the database, the project's git,
    # where to print, the time (#now, #pause) and the pipeline (#start a run,
    # #watch the database for slow suites that died).
    Context = Data.define(:db, :git, :io, :clock, :pipeline)
  end
end
