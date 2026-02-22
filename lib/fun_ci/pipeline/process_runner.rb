# frozen_string_literal: true

module FunCi
  module Pipeline
    module ProcessRunner
      def run_process_with_timeout(cmd, budget)
        r, w = IO.pipe
        pid = Process.spawn(cmd, out: w, err: w, pgroup: true)
        w.close

        reader = Thread.new { r.read }

        if reader.join(budget)
          output = reader.value
          _, status = Process.waitpid2(pid)
          [output, status, false]
        else
          Process.kill("TERM", -pid) rescue nil
          Process.kill("KILL", -pid) rescue nil
          Process.waitpid(pid) rescue nil
          ["", nil, true]
        end
      ensure
        r&.close rescue nil
      end
    end
  end
end
