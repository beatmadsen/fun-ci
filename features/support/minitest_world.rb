# frozen_string_literal: true

require "minitest"

module MinitestWorld
  include Minitest::Assertions

  attr_accessor :assertions

  def initialize
    self.assertions = 0
    super
  end
end
