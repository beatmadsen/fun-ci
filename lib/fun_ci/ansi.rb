# frozen_string_literal: true

module FunCi
  module Ansi
    RESET = "\e[0m"

    def self.green(text)      = "\e[32m#{text}#{RESET}"
    def self.bold_green(text)  = "\e[1;32m#{text}#{RESET}"
    def self.bold_red(text)    = "\e[1;31m#{text}#{RESET}"
    def self.bold_yellow(text) = "\e[1;33m#{text}#{RESET}"
    def self.cyan(text)        = "\e[36m#{text}#{RESET}"
    def self.bold_cyan(text)   = "\e[1;36m#{text}#{RESET}"
    def self.dim(text)         = "\e[2m#{text}#{RESET}"
    def self.white(text)       = "\e[37m#{text}#{RESET}"
    def self.bg_charcoal(text) = "\e[48;5;236m#{text}#{RESET}"

    def self.strip(text)
      text.gsub(/\e\[[0-9;]*[A-Za-z]/, "")
    end
  end
end
