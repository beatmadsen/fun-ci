# frozen_string_literal: true

require "open3"

# Whether a process is still running. Signal 0 answers for a process that was
# killed but not yet reaped (a zombie) as for a live one, so a zombie, which
# ps shows in state Z, counts as not running. For process tests only.
module ProcessState
  def self.running?(pid)
    Process.kill(0, pid)
    !Open3.capture2("ps", "-o", "stat=", "-p", pid.to_s).first.strip.start_with?("Z")
  rescue Errno::ESRCH
    false
  end
end
