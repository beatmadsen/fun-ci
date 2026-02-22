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
    def self.bold_white(text)  = "\e[1;37m#{text}#{RESET}"
    def self.white(text)       = "\e[37m#{text}#{RESET}"
    def self.yellow(text)      = "\e[33m#{text}#{RESET}"
    def self.dim_green(text)   = "\e[2;32m#{text}#{RESET}"
    def self.dim_red(text)     = "\e[2;31m#{text}#{RESET}"
    def self.orange(text)      = "\e[38;5;208m#{text}#{RESET}"
    def self.dark_red(text)    = "\e[38;5;52m#{text}#{RESET}"
    def self.bg_charcoal(text) = "\e[48;5;236m#{text}#{RESET}"
    def self.bg_dark_red(text)    = "\e[48;5;124m#{text}#{RESET}"
    def self.bg_orange(text)      = "\e[48;5;166m#{text}#{RESET}"
    def self.bg_very_dark_red(text) = "\e[48;5;52m#{text}#{RESET}"
    def self.bg_dark_green(text)  = "\e[48;5;22m#{text}#{RESET}"
    def self.bg_dark_yellow(text) = "\e[48;5;58m#{text}#{RESET}"

    def self.strip(text)
      text.gsub(/\e\[[0-9;]*[A-Za-z]/, "")
    end
  end
end
