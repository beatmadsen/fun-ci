# frozen_string_literal: true

module FunCi
  class ProjectDetector
    def initialize(filenames)
      @filenames = filenames
    end

    def detect
      return :ruby_bundler if @filenames.include?("Gemfile")

      :unknown
    end
  end
end
