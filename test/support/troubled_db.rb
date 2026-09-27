# frozen_string_literal: true

require "sqlite3"
require "tmpdir"

# A database whose every statement fails with `error`, as a database stays
# locked past its busy timeout, or a full disk refuses a write. It names a
# path in the test's temp root, since fun-ci keeps files beside a database.
class TroubledDb
  PATH = File.join(Dir.tmpdir, "troubled", "db.sqlite3")

  def initialize(error)
    @error = error
  end

  def execute(*) = raise(@error, "simulated")
  def filename(_name) = PATH
  def close = nil
end
