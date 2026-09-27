# frozen_string_literal: true

require_relative "body_script"

# Shell scripts that play the renderer's part for the console's process
# tests. QUITS shakes hands, waits for the board, presses `q` and waits for
# `quit`, noting each line it reads in "<script>.heard"; DIES answers `hello`
# and exits 3; GRUMBLES writes to stderr, then does what QUITS does;
# CRASHES_ON_QUIT does what QUITS does, then exits 3.
module FakeRenderers
  QUITS = <<~SH
    read -r line; echo "$line" >> "$0.heard"
    echo '{"t":"ready","v":1,"cols":80,"rows":24}'
    read -r line; echo "$line" >> "$0.heard"
    echo '{"t":"key","key":"q"}'
    read -r line; echo "$line" >> "$0.heard"
  SH
  DIES = <<~SH
    read -r line
    echo '{"t":"ready","v":1,"cols":80,"rows":24}'
    exit 3
  SH
  GRUMBLES = "echo 'the renderer grumbles' >&2\n#{QUITS}".freeze
  CRASHES_ON_QUIT = "#{QUITS}exit 3\n".freeze

  # Writes `script` as an executable renderer in `dir`; answers its path.
  def self.write(dir, script) = BodyScript.write(File.join(dir, "renderer"), script)
end
