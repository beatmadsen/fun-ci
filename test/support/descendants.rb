# frozen_string_literal: true

# Runs a command with one end of a pipe as fd 3. Every process it starts
# inherits that end, unless it closes it, so reading the pipe to its end
# waits exactly until the command and everything it started have finished,
# with no polling.
module Descendants
  Watch = Struct.new(:pid, :pipe) do
    # The command's own exit status, once all of them have finished.
    def wait_for_all
      pipe.read
      Process.wait2(pid).last
    end
  end

  def self.spawn(env, *command, **)
    all_gone, held = IO.pipe
    pid = Process.spawn(env, *command, 3 => held, **)
    held.close
    Watch.new(pid, all_gone)
  end
end
