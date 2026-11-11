# frozen_string_literal: true

module FunCi
  module Persistence
    # When a commit arrived on its branch: its first run there. A commit run
    # again (by a waiter, or `fun-ci trigger` by hand) keeps its place, so it
    # supersedes no commit that arrived after it, and takes no branch's row
    # from one (acceptance-tests.md, AT-9.20).
    module Arrival
      # The first run of the commit of the row `pipeline_runs` names, in SQL.
      FIRST_RUN = "(SELECT MIN(arrived.id) FROM pipeline_runs arrived " \
                  "WHERE arrived.project_path IS pipeline_runs.project_path " \
                  "AND arrived.branch = pipeline_runs.branch AND arrived.commit_hash = pipeline_runs.commit_hash)"
      # Later than any run: the place of a commit with no run yet.
      NOT_YET = 9_223_372_036_854_775_807
    end
  end
end
