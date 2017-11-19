module Carat
  class CLI::Exec
    attr_reader :options, :args, :cmd

    def initialize(options, args)
      @options = options
      @cmd = args.shift
      @args = args

      if RUBY_VERSION >= "2.0"
        @args << { :close_others => !options.keep_file_descriptors? }
      elsif options.keep_file_descriptors?
        Carat.ui.warn "Ruby version #{RUBY_VERSION} defaults to keeping non-standard file descriptors on Kernel#exec."
      end
    end

    def run
      raise ArgumentError if cmd.nil?

      # First, try to exec directly to something in PATH
      SharedHelpers.set_bundle_environment
      bin_path = Carat.which(@cmd)
      if bin_path
        Kernel.exec(bin_path, *args)
      end

      # If that didn't work, set up the whole bundle
      Carat.definition.validate_ruby!
      Carat.load.setup_environment
      Kernel.exec(@cmd, *args)
    rescue Errno::EACCES
      Carat.ui.error "carat: not executable: #{cmd}"
      exit 126
    rescue Errno::ENOENT
      Carat.ui.error "carat: command not found: #{cmd}"
      Carat.ui.warn  "Install missing gem executables with `bundle install`"
      exit 127
    rescue ArgumentError
      Carat.ui.error "carat: exec needs a command to run"
      exit 128
    end

  end
end
