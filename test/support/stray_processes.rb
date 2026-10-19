# frozen_string_literal: true

# The live processes whose command lines name a directory, such as a stage
# or job script run from a test's project, and stopping them. Read from ps,
# not from what the code under test recorded, which a mutant may have
# stopped it recording. Zombies name no path, so one already dead and not
# yet reaped is never among them.
module StrayProcesses
  # Kills the process group of each live process naming one of `dirs`, all
  # but this process's own, whose stray members are killed alone, and
  # answers them, as "pid command" lines. A group goes whole: a member found
  # before its leader, or whose leader names nothing, must not be killed
  # alone while the rest of its group carries on. `holders`: pids found
  # otherwise (OpenFiles), stopped likewise.
  def self.stop(dirs, holders: []) = kill_all(naming(dirs.map { |dir| "#{dir}/" }, holders))

  # Kills each of `found` (pid => [process group, command line]) as stop does.
  def self.kill_all(found)
    found.each { |pid, (group, _)| kill(pid, group) }
    found.map { |pid, (_, command)| "#{pid} #{command}" }
  end

  # pid => [process group, command line], of each live process naming one of `prefixes`, or among `holders`.
  def self.naming(prefixes, holders)
    listed = `ps -A -o pid= -o pgid= -o stat= -o command=`.lines.map { |line| line.strip.split(" ", 4) }
    listed.select { |pid, _, stat, command| live?(stat) && found?(pid.to_i, command.to_s, prefixes, holders) }
          .to_h { |pid, group, _, command| [pid.to_i, [group.to_i, command]] }
  end

  def self.live?(stat) = !stat.start_with?("Z")

  def self.found?(pid, command, prefixes, holders)
    holders.include?(pid) || prefixes.any? { |dir| command.include?(dir) }
  end

  # Gone: ESRCH, or on macOS EPERM for a group left with only zombies. The
  # processes found name a test temp root, private to this user.
  def self.kill(pid, group)
    Process.kill("KILL", group == Process.getpgrp ? pid : -group)
  rescue Errno::ESRCH, Errno::EPERM
    nil
  end
  private_class_method :naming, :live?, :found?, :kill
end
