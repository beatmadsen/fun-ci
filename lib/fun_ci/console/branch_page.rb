# frozen_string_literal: true

module FunCi
  module Console
    # A page of the board's branch rows (BoardData#runs), and whether there
    # are more branches in view beyond it.
    BranchPage = Data.define(:runs, :more)
  end
end
