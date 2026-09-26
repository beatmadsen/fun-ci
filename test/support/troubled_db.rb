# frozen_string_literal: true

require "sqlite3"

# A database whose every statement fails with `error`, as a database stays
# locked past its busy timeout, or a full disk refuses a write.
class TroubledDb
  PATH = "/var/fun-ci/db.sqlite3"

  def initialize(error)
    @error = error
  end

  def execute(*) = raise(@error, "simulated")
  def filename(_name) = PATH
  def close = nil
end
