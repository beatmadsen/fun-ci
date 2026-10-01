# frozen_string_literal: true

module FunCi
  module Console
    # How many branches BoardData loads: a page of `page_size` at first, a
    # page more each time the cursor reaches the last one loaded.
    class Paging
      attr_reader :limit

      def initialize(page_size)
        @page_size = page_size
        @limit = page_size
      end

      def load_more
        @limit += @page_size
      end

      # Pages by `page_size` from now on, loading at least one such page.
      def resize(page_size)
        @page_size = page_size
        @limit = [@limit, page_size].max
      end
    end
  end
end
