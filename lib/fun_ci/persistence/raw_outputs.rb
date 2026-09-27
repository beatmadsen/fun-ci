# frozen_string_literal: true

require "fileutils"
require "zlib"

module FunCi
  module Persistence
    # What each failed stage printed, masked and cut to its window, kept as a
    # gzip file per stage in a directory beside the database: SQLite would
    # not give a deleted blob's space back without a VACUUM (architecture.md, "Evidence of a failed stage").
    class RawOutputs
      def self.beside(db_path) = new(File.join(File.dirname(db_path), "raw"))

      def initialize(dir)
        @dir = dir
      end

      def write(job_id, text)
        FileUtils.mkdir_p(@dir)
        Zlib::GzipWriter.open(path(job_id)) { |gzip| gzip.write(text) }
      end

      def read(job_id)
        File.exist?(path(job_id)) ? Zlib::GzipReader.open(path(job_id), &:read) : nil
      end

      # How many bytes it kept, from the size gzip records at the file's end.
      def bytes(job_id)
        File.exist?(path(job_id)) ? File.binread(path(job_id), 4, File.size(path(job_id)) - 4).unpack1("V") : nil
      end

      def delete(job_ids) = job_ids.each { |job_id| FileUtils.rm_f(path(job_id)) }

      # Deletes what it kept of every stage but those named.
      def keep_only(job_ids)
        kept = job_ids.to_set(&:to_s)
        Dir.glob("*.gz", base: @dir).reject { |name| kept.include?(File.basename(name, ".gz")) }
           .each { |name| FileUtils.rm_f(File.join(@dir, name)) }
      end

      private

      def path(job_id) = File.join(@dir, "#{job_id}.gz")
    end
  end
end
