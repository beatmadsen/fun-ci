# frozen_string_literal: true

module FunCi
  module Agent
    # What every agent command answers from: the database, the project's git,
    # where to print, the time (#now, #pause) and the pipeline (#start a run,
    # #watch the database for slow suites that died) and the trunk as the
    # project's git has it now (#now_at(tip), #check(sha, fetches)).
    Context = Data.define(:db, :git, :io, :clock, :pipeline, :trunk)
  end
end
