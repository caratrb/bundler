# frozen_string_literal: true

require "carat/compatibility_guard"

require "pathname"
require "rubygems"

require "carat/version"
require "carat/constants"
require "carat/rubygems_integration"
require "carat/current_ruby"

module Gem
  class Dependency
    # This is only needed for RubyGems < 1.4
    unless method_defined? :requirement
      def requirement
        version_requirements
      end
    end
  end
end

module Carat
  module SharedHelpers
    def root
      gemfile = find_gemfile
      raise GemfileNotFound, "Could not locate Gemfile" unless gemfile
      Pathname.new(gemfile).untaint.expand_path.parent
    end

    def default_gemfile
      gemfile = find_gemfile(:order_matters)
      raise GemfileNotFound, "Could not locate Gemfile" unless gemfile
      Pathname.new(gemfile).untaint.expand_path
    end

    def default_lockfile
      gemfile = default_gemfile

      case gemfile.basename.to_s
      when "gems.rb" then Pathname.new(gemfile.sub(/.rb$/, ".locked"))
      else Pathname.new("#{gemfile}.lock")
      end.untaint
    end

    def default_carat_dir
      carat_dir = find_directory(".carat")
      return nil unless carat_dir

      carat_dir = Pathname.new(carat_dir)

      global_carat_dir = Carat.user_home.join(".carat")
      return nil if carat_dir == global_carat_dir

      carat_dir
    end

    def in_carat?
      find_gemfile
    end

    def chdir(dir, &blk)
      Carat.rubygems.ext_lock.synchronize do
        Dir.chdir dir, &blk
      end
    end

    def pwd
      Carat.rubygems.ext_lock.synchronize do
        Pathname.pwd
      end
    end

    def with_clean_git_env(&block)
      keys    = %w[GIT_DIR GIT_WORK_TREE]
      old_env = keys.inject({}) do |h, k|
        h.update(k => ENV[k])
      end

      keys.each {|key| ENV.delete(key) }

      block.call
    ensure
      keys.each {|key| ENV[key] = old_env[key] }
    end

    def set_carat_environment
      set_carat_variables
      set_path
      set_rubyopt
      set_rubylib
    end

    # Rescues permissions errors raised by file system operations
    # (ie. Errno:EACCESS, Errno::EAGAIN) and raises more friendly errors instead.
    #
    # @param path [String] the path that the action will be attempted to
    # @param action [Symbol, #to_s] the type of operation that will be
    #   performed. For example: :write, :read, :exec
    #
    # @yield path
    #
    # @raise [Carat::PermissionError] if Errno:EACCES is raised in the
    #   given block
    # @raise [Carat::TemporaryResourceError] if Errno:EAGAIN is raised in the
    #   given block
    #
    # @example
    #   filesystem_access("vendor/cache", :write) do
    #     FileUtils.mkdir_p("vendor/cache")
    #   end
    #
    # @see {Carat::PermissionError}
    def filesystem_access(path, action = :write, &block)
      # Use block.call instead of yield because of a bug in Ruby 2.2.2
      # See https://github.com/caratrb/carat/issues/5341 for details
      block.call(path.dup.untaint)
    rescue Errno::EACCES
      raise PermissionError.new(path, action)
    rescue Errno::EAGAIN
      raise TemporaryResourceError.new(path, action)
    rescue Errno::EPROTO
      raise VirtualProtocolError.new
    rescue Errno::ENOSPC
      raise NoSpaceOnDeviceError.new(path, action)
    rescue *[const_get_safely(:ENOTSUP, Errno)].compact
      raise OperationNotSupportedError.new(path, action)
    rescue Errno::EEXIST, Errno::ENOENT
      raise
    rescue SystemCallError => e
      raise GenericSystemCallError.new(e, "There was an error accessing `#{path}`.")
    end

    def const_get_safely(constant_name, namespace)
      const_in_namespace = namespace.constants.include?(constant_name.to_s) ||
        namespace.constants.include?(constant_name.to_sym)
      return nil unless const_in_namespace
      namespace.const_get(constant_name)
    end

    def major_deprecation(major_version, message)
      if Carat.carat_major_version >= major_version
        require "carat/errors"
        raise DeprecatedError, "[REMOVED FROM #{major_version}.0] #{message}"
      end

      return unless prints_major_deprecations?
      @major_deprecation_ui ||= Carat::UI::Shell.new("no-color" => true)
      ui = Carat.ui.is_a?(@major_deprecation_ui.class) ? Carat.ui : @major_deprecation_ui
      ui.warn("[DEPRECATED FOR #{major_version}.0] #{message}")
    end

    def print_major_deprecations!
      multiple_gemfiles = search_up(".") do |dir|
        gemfiles = gemfile_names.select {|gf| File.file? File.expand_path(gf, dir) }
        next if gemfiles.empty?
        break false if gemfiles.size == 1
      end
      if multiple_gemfiles && Carat.carat_major_version == 1
        Carat::SharedHelpers.major_deprecation 2, \
          "gems.rb and gems.locked will be preferred to Gemfile and Gemfile.lock."
      end

      if RUBY_VERSION < "2"
        major_deprecation(2, "Carat will only support ruby >= 2.0, you are running #{RUBY_VERSION}")
      end
      return if Carat.rubygems.provides?(">= 2")
      major_deprecation(2, "Carat will only support rubygems >= 2.0, you are running #{Carat.rubygems.version}")
    end

    def trap(signal, override = false, &block)
      prior = Signal.trap(signal) do
        block.call
        prior.call unless override
      end
    end

    def ensure_same_dependencies(spec, old_deps, new_deps)
      new_deps = new_deps.reject {|d| d.type == :development }
      old_deps = old_deps.reject {|d| d.type == :development }

      without_type = proc {|d| Gem::Dependency.new(d.name, d.requirements_list.sort) }
      new_deps.map!(&without_type)
      old_deps.map!(&without_type)

      extra_deps = new_deps - old_deps
      return if extra_deps.empty?

      Carat.ui.debug "#{spec.full_name} from #{spec.remote} has either corrupted API or lockfile dependencies" \
        " (was expecting #{old_deps.map(&:to_s)}, but the real spec has #{new_deps.map(&:to_s)})"
      raise APIResponseMismatchError,
        "Downloading #{spec.full_name} revealed dependencies not in the API or the lockfile (#{extra_deps.join(", ")})." \
        "\nEither installing with `--full-index` or running `carat update #{spec.name}` should fix the problem."
    end

    def pretty_dependency(dep, print_source = false)
      msg = String.new(dep.name)
      msg << " (#{dep.requirement})" unless dep.requirement == Gem::Requirement.default
      if dep.is_a?(Carat::Dependency)
        platform_string = dep.platforms.join(", ")
        msg << " " << platform_string if !platform_string.empty? && platform_string != Gem::Platform::RUBY
      end
      msg << " from the `#{dep.source}` source" if print_source && dep.source
      msg
    end

    def md5_available?
      return @md5_available if defined?(@md5_available)
      @md5_available = begin
        require "openssl"
        OpenSSL::Digest::MD5.digest("")
        true
      rescue LoadError
        true
      rescue OpenSSL::Digest::DigestError
        false
      end
    end

  private

    def validate_carat_path
      path_separator = Carat.rubygems.path_separator
      return unless Carat.carat_path.to_s.split(path_separator).size > 1
      message = "Your carat path contains text matching #{path_separator.inspect}, " \
                "which is the path separator for your system. Carat cannot " \
                "function correctly when the Carat path contains the " \
                "system's PATH separator. Please change your " \
                "carat path to not match #{path_separator.inspect}." \
                "\nYour current carat path is '#{Carat.carat_path}'."
      raise Carat::PathError, message
    end

    def find_gemfile(order_matters = false)
      given = ENV["CARAT_GEMFILE"]
      return given if given && !given.empty?
      names = gemfile_names
      names.reverse! if order_matters && Carat.feature_flag.prefer_gems_rb?
      find_file(*names)
    end

    def gemfile_names
      ["Gemfile", "gems.rb"]
    end

    def find_file(*names)
      search_up(*names) do |filename|
        return filename if File.file?(filename)
      end
    end

    def find_directory(*names)
      search_up(*names) do |dirname|
        return dirname if File.directory?(dirname)
      end
    end

    def search_up(*names)
      previous = nil
      current  = File.expand_path(SharedHelpers.pwd).untaint

      until !File.directory?(current) || current == previous
        if ENV["CARAT_SPEC_RUN"]
          # avoid stepping above the tmp directory when testing
          return nil if File.file?(File.join(current, "carat.gemspec"))
        end

        names.each do |name|
          filename = File.join(current, name)
          yield filename
        end
        previous = current
        current = File.expand_path("..", current)
      end
    end

    def set_env(key, value)
      raise ArgumentError, "new key #{key}" unless EnvironmentPreserver::CARAT_KEYS.include?(key)
      orig_key = "#{EnvironmentPreserver::CARAT_PREFIX}#{key}"
      orig = ENV[key]
      orig ||= EnvironmentPreserver::INTENTIONALLY_NIL
      ENV[orig_key] ||= orig

      ENV[key] = value
    end
    public :set_env

    def set_carat_variables
      begin
        Carat::SharedHelpers.set_env "CARAT_BIN_PATH", Carat.rubygems.bin_path("carat", "carat", VERSION)
      rescue Gem::GemNotFoundException
        Carat::SharedHelpers.set_env "CARAT_BIN_PATH", File.expand_path("../../../exe/carat", __FILE__)
      end

      # Set CARAT_GEMFILE
      Carat::SharedHelpers.set_env "CARAT_GEMFILE", find_gemfile(:order_matters).to_s
      Carat::SharedHelpers.set_env "CARAT_VERSION", Carat::VERSION
    end

    def set_path
      validate_carat_path
      paths = (ENV["PATH"] || "").split(File::PATH_SEPARATOR)
      paths.unshift "#{Carat.carat_path}/bin"
      Carat::SharedHelpers.set_env "PATH", paths.uniq.join(File::PATH_SEPARATOR)
    end

    def set_rubyopt
      rubyopt = [ENV["RUBYOPT"]].compact
      return if !rubyopt.empty? && rubyopt.first =~ %r{-rcarat/setup}
      rubyopt.unshift %(-rcarat/setup)
      Carat::SharedHelpers.set_env "RUBYOPT", rubyopt.join(" ")
    end

    def set_rubylib
      rubylib = (ENV["RUBYLIB"] || "").split(File::PATH_SEPARATOR)
      rubylib.unshift carat_ruby_lib
      Carat::SharedHelpers.set_env "RUBYLIB", rubylib.uniq.join(File::PATH_SEPARATOR)
    end

    def carat_ruby_lib
      File.expand_path("../..", __FILE__)
    end

    def clean_load_path
      # handle 1.9 where system gems are always on the load path
      return unless defined?(::Gem)

      carat_lib = carat_ruby_lib

      loaded_gem_paths = Carat.rubygems.loaded_gem_paths

      $LOAD_PATH.reject! do |p|
        next if File.expand_path(p).start_with?(carat_lib)
        loaded_gem_paths.delete(p)
      end
      $LOAD_PATH.uniq!
    end

    def prints_major_deprecations?
      require "carat"
      deprecation_release = Carat::VERSION.split(".").drop(1).include?("99")
      return false if !deprecation_release && !Carat.settings[:major_deprecations]
      require "carat/deprecate"
      return false if Carat::Deprecate.skip
      true
    end

    extend self
  end
end
