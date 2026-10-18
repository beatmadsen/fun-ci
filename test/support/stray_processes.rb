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
  # alone while the rest of its group carries on.
  def self.stop(dirs) = kill_all(naming(dirs.map { |dir| "#{dir}/" }))

  # Kills each of `found` (pid => [process group, command line]) as stop does.
  def self.kill_all(found)
    found.each { |pid, (group, _)| kill(pid, group) }
    found.map { |pid, (_, command)| "#{pid} #{command}" }
  end

  # pid => [process group, command line], of each live process naming one of `prefixes`.
  def self.naming(prefixes)
    listed = `ps -A -o pid= -o pgid= -o stat= -o command=`.lines.map { |line| line.strip.split(" ", 4) }
    listed.select { |_, _, stat, command| live_in?(stat, command.to_s, prefixes) }
          .to_h { |pid, group, _, command| [pid.to_i, [group.to_i, command]] }
  end

  def self.live_in?(stat, command, prefixes) = !stat.start_with?("Z") && prefixes.any? { |dir| command.include?(dir) }

  # Gone: ESRCH, or on macOS EPERM for a group left with only zombies. The
  # processes found name a test temp root, private to this user.
  def self.kill(pid, group)
    Process.kill("KILL", group == Process.getpgrp ? pid : -group)
  rescue Errno::ESRCH, Errno::EPERM
    nil
  end
  private_class_method :naming, :live_in?, :kill
end
