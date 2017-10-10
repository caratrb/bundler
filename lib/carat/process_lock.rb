# frozen_string_literal: true

module Carat
  class ProcessLock
    def self.lock(carat_path = Carat.carat_path)
      lock_file_path = File.join(carat_path, "carat.lock")
      has_lock = false

      File.open(lock_file_path, "w") do |f|
        f.flock(File::LOCK_EX)
        has_lock = true
        yield
        f.flock(File::LOCK_UN)
      end
    rescue Errno::EACCES, Errno::ENOLCK
      # In the case the user does not have access to
      # create the lock file or is using NFS where
      # locks are not available we skip locking.
      yield
    ensure
      FileUtils.rm_f(lock_file_path) if has_lock
    end
  end
end
