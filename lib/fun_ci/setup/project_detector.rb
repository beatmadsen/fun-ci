# frozen_string_literal: true

module FunCi
  module Setup
    class ProjectDetector
      def initialize(filenames)
        @filenames = filenames
      end

      def detect
        return :ruby_bundler if @filenames.include?("Gemfile")
        return :jvm_gradle_kotlin if @filenames.include?("build.gradle.kts")
        return :jvm_gradle_kotlin if @filenames.include?("settings.gradle.kts")
        return :jvm_gradle_groovy if @filenames.include?("build.gradle")
        return :jvm_gradle_groovy if @filenames.include?("settings.gradle")
        return :jvm_maven if @filenames.include?("pom.xml")

        :unknown
      end
    end
  end
end
