# frozen_string_literal: true

require_relative "../evidence/document"
require_relative "../trunk/check"
require_relative "../trunk/regions"

module FunCi
  module Agent
    # A conflict with the trunk, merged again, as the evidence `why REV trunk`
    # prints (docs/trunk-conflicts.md, why REV trunk): git's messages, then
    # each conflicted region under its file, its lines numbered as the file's.
    module TrunkWhy
      EXTRACTOR = "merge-tree"

      # explained: a Trunk::Explained, or nil when the commits are gone.
      def self.document(explained, tip)
        return gone(tip) unless explained

        Evidence::Document.new(chosen: [], facts: [], failures: [], problems: [],
                               excerpts: [messages(explained.messages), *explained.files.flat_map do |path, text|
                                 regions(path, text)
                               end])
      end

      def self.messages(lines) = { title: "Git's messages", location: "merge", lines: lines, extractor: EXTRACTOR }

      def self.regions(path, text)
        Trunk::Regions.of(text).map do |region|
          { title: path, location: "lines #{region.first}-#{region.last}", extractor: EXTRACTOR,
            lines: region.lines.map { |number, line| "#{number.to_s.rjust(4)}  #{line}" } }
        end
      end

      def self.gone(tip)
        problem = { extractor: EXTRACTOR,
                    message: "#{tip.ref} #{tip.sha[0, 7]} or the commit is no longer in this repository" }
        Evidence::Document.new(chosen: [], facts: [], failures: [], excerpts: [], problems: [problem])
      end
      private_class_method :messages, :regions, :gone
    end
  end
end
