# frozen_string_literal: true

module FunCi
  module Pipeline
    # Kills a process group and what left it (ProcessTree): TERM, then KILL.
    # A member forking as the KILL arrives leaves a child in the group that
    # the signal missed, so the group is killed again while any member lives,
    # a bounded number of times, since a mutant may stop it ever going.
    module GroupKill
      ROUNDS = 10

      # escaped: further targets, -pgid for a group, pid for a process.
      def self.kill(pid, escaped, signal: Process.method(:kill))
        %w[TERM KILL].product([-pid, *escaped]).each { |name, target| send_to(signal, name, target) }
        ROUNDS.times do
          return unless lives?(pid, signal)

          send_to(signal, "KILL", -pid)
        end
      end

      # On macOS a group left with only zombies answers EPERM, not ESRCH.
      def self.lives?(pid, signal)
        signal.call(0, -pid)
        true
      rescue Errno::ESRCH, Errno::EPERM
        false
      end

      def self.send_to(signal, name, target)
        signal.call(name, target)
      rescue Errno::ESRCH, Errno::EPERM
        nil
      end
      private_class_method :lives?, :send_to
    end
  end
end
