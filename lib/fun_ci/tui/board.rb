# frozen_string_literal: true

module FunCi
  module Tui
    # Everything one frame of the status board shows. `now` is the frame's
    # clock, so relative times and elapsed seconds never read Time.now.
    Board = Data.define(:runs, :streak, :cursor_index, :confirming, :now)
  end
end
