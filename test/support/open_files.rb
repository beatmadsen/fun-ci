# frozen_string_literal: true

require "open3"

# The pids of this user's processes holding a file open under one of some
# directories, such as an output file a test's process inherited, whose
# command line may name no path at all. Linux lists each process's
# descriptors under /proc; macOS has lsof, which Linux images may lack.
module OpenFiles
  PROC = "/proc/self/fd"

  def self.holders(dirs)
    prefixes = dirs.flat_map { |dir| ["#{dir}/", "#{File.realpath(dir)}/"] }.uniq
    found = File.directory?(PROC) ? from_proc(prefixes) : from_lsof(prefixes)
    found - [Process.pid]
  end

  def self.from_proc(prefixes)
    held = Dir.glob("/proc/[0-9]*").select { |dir| targets("#{dir}/fd").any? { |path| under?(path, prefixes) } }
    held.map { |dir| File.basename(dir).to_i }
  end

  def self.targets(fds)
    Dir.glob("#{fds}/*").filter_map { |link| File.readlink(link) }
  rescue SystemCallError
    []
  end

  # lsof's field output: a "p<pid>" line, then an "n<name>" line for each file it holds.
  def self.from_lsof(prefixes)
    listing, = Open3.capture2("lsof", "-n", "-w", "-u", Process.uid.to_s, "-Fpn", in: File::NULL, err: File::NULL)
    pids = listing.lines(chomp: true).slice_before(/\Ap/).filter_map { |lines| holder(lines, prefixes) }
    pids.uniq
  end

  def self.holder(lines, prefixes)
    lines.first[1..].to_i if lines.drop(1).any? { |line| under?(line[1..], prefixes) }
  end

  def self.under?(path, prefixes) = prefixes.any? { |prefix| path.start_with?(prefix) }
  private_class_method :from_proc, :targets, :from_lsof, :holder, :under?
end
