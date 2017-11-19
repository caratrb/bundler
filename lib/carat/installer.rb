require 'erb'
require 'rubygems/dependency_installer'
require 'carat/worker'

module Carat
  class Installer < Environment
    class << self
      attr_accessor :post_install_messages, :ambiguous_gems

      Installer.post_install_messages = {}
      Installer.ambiguous_gems = []
    end

    # Begins the installation process for Carat.
    # For more information see the #run method on this class.
    def self.install(root, definition, options = {})
      installer = new(root, definition)
      installer.run(options)
      installer
    end

    # Runs the install procedures for a specific Gemfile.
    #
    # Firstly, this method will check to see if Carat.bundle_path exists
    # and if not then will create it. This is usually the location of gems
    # on the system, be it RVM or at a system path.
    #
    # Secondly, it checks if Carat has been configured to be "frozen"
    # Frozen ensures that the Gemfile and the Gemfile.lock file are matching.
    # This stops a situation where a developer may update the Gemfile but may not run
    # `bundle install`, which leads to the Gemfile.lock file not being correctly updated.
    # If this file is not correctly updated then any other developer running
    # `bundle install` will potentially not install the correct gems.
    #
    # Thirdly, Carat checks if there are any dependencies specified in the Gemfile using
    # Carat::Environment#dependencies. If there are no dependencies specified then
    # Carat returns a warning message stating so and this method returns.
    #
    # Fourthly, Carat checks if the default lockfile (Gemfile.lock) exists, and if so
    # then proceeds to set up a defintion based on the default gemfile (Gemfile) and the
    # default lock file (Gemfile.lock). However, this is not the case if the platform is different
    # to that which is specified in Gemfile.lock, or if there are any missing specs for the gems.
    #
    # Fifthly, Carat resolves the dependencies either through a cache of gems or by remote.
    # This then leads into the gems being installed, along with stubs for their executables,
    # but only if the --binstubs option has been passed or Carat.options[:bin] has been set
    # earlier.
    #
    # Sixthly, a new Gemfile.lock is created from the installed gems to ensure that the next time
    # that a user runs `bundle install` they will receive any updates from this process.
    #
    # Finally: TODO add documentation for how the standalone process works.
    def run(options)
      create_bundle_path

      if Carat.settings[:frozen]
        @definition.ensure_equivalent_gemfile_and_lockfile(options[:deployment])
      end

      if dependencies.empty?
        Carat.ui.warn "The Gemfile specifies no dependencies"
        lock
        return
      end

      if Carat.default_lockfile.exist? && !options["update"]
        local = Carat.ui.silence do
          begin
            tmpdef = Definition.build(Carat.default_gemfile, Carat.default_lockfile, nil)
            true unless tmpdef.new_platform? || tmpdef.missing_specs.any?
          rescue CaratError
          end
        end
      end

      # Since we are installing, we can resolve the definition
      # using remote specs
      unless local
        options["local"] ? @definition.resolve_with_cache! : @definition.resolve_remotely!
      end

      # the order that the resolver provides is significant, since
      # dependencies might actually affect the installation of a gem.
      # that said, it's a rare situation (other than rake), and parallel
      # installation is just SO MUCH FASTER. so we let people opt in.
      jobs = [Carat.settings[:jobs].to_i-1, 1].max
      if jobs > 1 && can_install_in_parallel?
        install_in_parallel jobs, options[:standalone]
      else
        install_sequentially options[:standalone]
      end

      lock unless Carat.settings[:frozen]
      generate_standalone(options[:standalone]) if options[:standalone]
    end

    def install_gem_from_spec(spec, standalone = false, worker = 0)
      # Fetch the build settings, if there are any
      settings = Carat.settings["build.#{spec.name}"]
      messages = nil

      if settings
        Carat.rubygems.with_build_args [settings] do
          messages = spec.source.install(spec)
        end
      else
        messages = spec.source.install(spec)
      end

      install_message, post_install_message, debug_message = *messages

      if install_message.include? 'Installing'
        Carat.ui.confirm install_message
      else
        Carat.ui.info install_message
      end
      Carat.ui.debug debug_message if debug_message
      Carat.ui.debug "#{worker}:  #{spec.name} (#{spec.version}) from #{spec.loaded_from}"

      if Carat.settings[:bin] && standalone
        generate_standalone_carat_executable_stubs(spec)
      elsif Carat.settings[:bin]
        generate_carat_executable_stubs(spec, :force => true)
      end

      post_install_message
    rescue Errno::ENOSPC
      raise Carat::InstallError, "Your disk is out of space. Free some " \
        "space to be able to install your bundle."
    rescue Exception => e
      # if install hook failed or gem signature is bad, just die
      raise e if e.is_a?(Carat::InstallHookError) || e.is_a?(Carat::SecurityError)

      # other failure, likely a native extension build failure
      Carat.ui.info ""
      Carat.ui.warn "#{e.class}: #{e.message}"
      msg = "An error occurred while installing #{spec.name} (#{spec.version}),"
      msg << " and Carat cannot continue."

      unless spec.source.options["git"]
        msg << "\nMake sure that `gem install"
        msg << " #{spec.name} -v '#{spec.version}'` succeeds before bundling."
      end
      Carat.ui.debug e.backtrace.join("\n")
      raise Carat::InstallError, msg
    end

    def generate_carat_executable_stubs(spec, options = {})
      if options[:binstubs_cmd] && spec.executables.empty?
        options = {}
        spec.runtime_dependencies.each do |dep|
          bins = @definition.specs[dep].first.executables
          options[dep.name] = bins unless bins.empty?
        end
        if options.any?
          Carat.ui.warn "#{spec.name} has no executables, but you may want " +
            "one from a gem it depends on."
          options.each{|name,bins| Carat.ui.warn "  #{name} has: #{bins.join(', ')}" }
        else
          Carat.ui.warn "There are no executables for the gem #{spec.name}."
        end
        return
      end

      # double-assignment to avoid warnings about variables that will be used by ERB
      bin_path = bin_path = Carat.bin_path
      template = template = File.read(File.expand_path('../templates/Executable', __FILE__))
      relative_gemfile_path = relative_gemfile_path = Carat.default_gemfile.relative_path_from(bin_path)
      ruby_command = ruby_command = Thor::Util.ruby_command

      exists = []
      spec.executables.each do |executable|
        next if executable == "bundle"

        binstub_path = "#{bin_path}/#{executable}"
        if File.exist?(binstub_path) && !options[:force]
          exists << executable
          next
        end

        File.open(binstub_path, 'w', 0777 & ~File.umask) do |f|
          f.puts ERB.new(template, nil, '-').result(binding)
        end
      end

      if options[:binstubs_cmd] && exists.any?
        case exists.size
        when 1
          Carat.ui.warn "Skipped #{exists[0]} since it already exists."
        when 2
          Carat.ui.warn "Skipped #{exists.join(' and ')} since they already exist."
        else
          items = exists[0...-1].empty? ? nil : exists[0...-1].join(', ')
          skipped = [items, exists[-1]].compact.join(' and ')
          Carat.ui.warn "Skipped #{skipped} since they already exist."
        end
        Carat.ui.warn "If you want to overwrite skipped stubs, use --force."
      end
    end

  private

    def can_install_in_parallel?
      if Carat.rubygems.provides?(">= 2.1.0")
        true
      else
        Carat.ui.warn "Rubygems #{Gem::VERSION} is not threadsafe, so your "\
          "gems must be installed one at a time. Upgrade to Rubygems 2.1.0 " \
          "or higher to enable parallel gem installation."
        false
      end
    end

    def generate_standalone_carat_executable_stubs(spec)
      # double-assignment to avoid warnings about variables that will be used by ERB
      bin_path = Carat.bin_path
      template = File.read(File.expand_path('../templates/Executable.standalone', __FILE__))
      ruby_command = ruby_command = Thor::Util.ruby_command

      spec.executables.each do |executable|
        next if executable == "bundle"
        standalone_path = standalone_path = Pathname(Carat.settings[:path]).expand_path.relative_path_from(bin_path)
        executable_path = executable_path = Pathname(spec.full_gem_path).join(spec.bindir, executable).relative_path_from(bin_path)
        File.open "#{bin_path}/#{executable}", 'w', 0755 do |f|
          f.puts ERB.new(template, nil, '-').result(binding)
        end
      end
    end

    def generate_standalone(groups)
      standalone_path = Carat.settings[:path]
      carat_path = File.join(standalone_path, "carat")
      FileUtils.mkdir_p(carat_path)

      paths = []

      if groups.empty?
        specs = @definition.requested_specs
      else
        specs = @definition.specs_for groups.map { |g| g.to_sym }
      end

      specs.each do |spec|
        next if spec.name == "carat"
        next if spec.require_paths.nil? # builtin gems

        spec.require_paths.each do |path|
          full_path = File.join(spec.full_gem_path, path)
          gem_path = Pathname.new(full_path).relative_path_from(Carat.root.join(carat_path))
          paths << gem_path.to_s.sub("#{Carat.ruby_version.engine}/#{RbConfig::CONFIG['ruby_version']}", '#{ruby_engine}/#{ruby_version}')
        end
      end


      File.open File.join(carat_path, "setup.rb"), "w" do |file|
        file.puts "require 'rbconfig'"
        file.puts "# ruby 1.8.7 doesn't define RUBY_ENGINE"
        file.puts "ruby_engine = defined?(RUBY_ENGINE) ? RUBY_ENGINE : 'ruby'"
        file.puts "ruby_version = RbConfig::CONFIG[\"ruby_version\"]"
        file.puts "path = File.expand_path('..', __FILE__)"
        paths.each do |path|
          file.puts %{$:.unshift "\#{path}/#{path}"}
        end
      end
    end

    def install_sequentially(standalone)
      specs.each do |spec|
        message = install_gem_from_spec spec, standalone, 0
        if message
          Installer.post_install_messages[spec.name] = message
        end
      end
    end

    def install_in_parallel(size, standalone)
      name2spec = {}
      remains = {}
      enqueued = {}
      specs.each do |spec|
        name2spec[spec.name] = spec
        remains[spec.name] = true
      end

      worker_pool = Worker.new size, lambda { |name, worker_num|
        spec = name2spec[name]
        message = install_gem_from_spec spec, standalone, worker_num
        { :name => spec.name, :post_install => message }
      }

      # Keys in the remains hash represent uninstalled gems specs.
      # We enqueue all gem specs that do not have any dependencies.
      # Later we call this lambda again to install specs that depended on
      # previously installed specifications. We continue until all specs
      # are installed.
      enqueue_remaining_specs = lambda do
        remains.keys.each do |name|
          next if enqueued[name]
          spec = name2spec[name]
          if ready_to_install?(spec, remains)
            worker_pool.enq name
            enqueued[name] = true
          end
        end
      end
      enqueue_remaining_specs.call

      until remains.empty?
        message = worker_pool.deq
        remains.delete message[:name]
        if message[:post_install]
          Installer.post_install_messages[message[:name]] = message[:post_install]
        end
        enqueue_remaining_specs.call
      end
      message
    ensure
      worker_pool && worker_pool.stop
    end

    # We only want to install a gem spec if all its dependencies are met.
    # If the dependency is no longer in the `remains` hash then it has been met.
    # If a dependency is only development or is self referential it can be ignored.
    def ready_to_install?(spec, remains)
      spec.dependencies.none? do |dep|
        next if dep.type == :development || dep.name == spec.name
        remains[dep.name]
      end
    end

    def create_bundle_path
      Carat.mkdir_p(Carat.bundle_path.to_s) unless Carat.bundle_path.exist?
    rescue Errno::EEXIST
      raise PathError, "Could not install to path `#{Carat.settings[:path]}` " +
        "because of an invalid symlink. Remove the symlink so the directory can be created."
    end

  end
end
