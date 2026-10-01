# frozen_string_literal: true

# The live processes whose command lines name a directory, such as a stage
# or job script run from a test's project, and stopping them. Read from ps,
# not from what the code under test recorded, which a mutant may have
# stopped it recording. Zombies name no path, so one already dead and not
# yet reaped is never among them.
module StrayProcesses
  # Kills each live process naming one of `dirs` with its process group, and
  # answers them, as "pid command" lines.
  def self.stop(dirs)
    found = naming(dirs.map { |dir| "#{dir}/" })
    found.each_key { |pid| kill(pid) }
    found.map { |pid, command| "#{pid} #{command}" }
  end

  # pid => command line, of each live process naming one of `prefixes`.
  def self.naming(prefixes)
    listed = `ps -A -o pid= -o stat= -o command=`.lines.map { |line| line.strip.split(" ", 3) }
    listed.select { |_, stat, command| live_in?(stat, command.to_s, prefixes) }
          .to_h { |pid, _, command| [pid.to_i, command] }
  end

  def self.live_in?(stat, command, prefixes) = !stat.start_with?("Z") && prefixes.any? { |dir| command.include?(dir) }

  # One that leads no group of its own is killed alone.
  def self.kill(pid)
    Process.kill("KILL", -pid)
  rescue Errno::ESRCH, Errno::EPERM
    kill_alone(pid)
  end

  def self.kill_alone(pid)
    Process.kill("KILL", pid)
  rescue Errno::ESRCH
    nil
  end
  private_class_method :naming, :live_in?, :kill, :kill_alone
end
