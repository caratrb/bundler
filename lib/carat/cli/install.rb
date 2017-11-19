module Carat
  class CLI::Install
    attr_reader :options
    def initialize(options)
      @options = options
    end

    def run
      Carat.ui.level = "error" if options[:quiet]

      warn_if_root

      if options[:without]
        options[:without] = options[:without].map{|g| g.tr(' ', ':') }
      end

      ENV['RB_USER_INSTALL'] = '1' if Carat::FREEBSD

      # Just disable color in deployment mode
      Carat.ui.shell = Thor::Shell::Basic.new if options[:deployment]

      if (options[:path] || options[:deployment]) && options[:system]
        Carat.ui.error "You have specified both a path to install your gems to, \n" \
                         "as well as --system. Please choose."
        exit 1
      end

      if (options["trust-policy"])
        unless (Carat.rubygems.security_policies.keys.include?(options["trust-policy"]))
          Carat.ui.error "Rubygems doesn't know about trust policy '#{options["trust-policy"]}'. " \
            "The known policies are: #{Carat.rubygems.security_policies.keys.join(', ')}."
          exit 1
        end
        Carat.settings["trust-policy"] = options["trust-policy"]
      else
        Carat.settings["trust-policy"] = nil if Carat.settings["trust-policy"]
      end

      if options[:deployment] || options[:frozen]
        unless Carat.default_lockfile.exist?
          flag = options[:deployment] ? '--deployment' : '--frozen'
          raise ProductionError, "The #{flag} flag requires a Gemfile.lock. Please make " \
                                 "sure you have checked your Gemfile.lock into version control " \
                                 "before deploying."
        end

        if Carat.app_cache.exist?
          options[:local] = true
        end

        Carat.settings[:frozen] = '1'
      end

      # When install is called with --no-deployment, disable deployment mode
      if options[:deployment] == false
        Carat.settings.delete(:frozen)
        options[:system] = true
      end

      Carat.settings[:path]     = nil if options[:system]
      Carat.settings[:path]     = "vendor/bundle" if options[:deployment]
      Carat.settings[:path]     = options["path"] if options["path"]
      Carat.settings[:path]     ||= "bundle" if options["standalone"]
      Carat.settings[:bin]      = options["binstubs"] if options["binstubs"]
      Carat.settings[:bin]      = nil if options["binstubs"] && options["binstubs"].empty?
      Carat.settings[:shebang]  = options["shebang"] if options["shebang"]
      Carat.settings[:jobs]     = options["jobs"] if options["jobs"]
      Carat.settings[:no_prune] = true if options["no-prune"]
      Carat.settings[:no_install] = true if options["no-install"]
      Carat.settings[:clean]    = options["clean"] if options["clean"]
      Carat.settings.without    = options[:without]
      Carat::Fetcher.disable_endpoint = options["full-index"]
      Carat.settings[:disable_shared_gems] = Carat.settings[:path] ? '1' : nil

      # rubygems plugins sometimes hook into the gem install process
      Gem.load_env_plugins if Gem.respond_to?(:load_env_plugins)

      definition = Carat.definition
      definition.validate_ruby!
      Installer.install(Carat.root, definition, options)
      Carat.load.cache if Carat.app_cache.exist? && !options["no-cache"] && !Carat.settings[:frozen]

      Carat.ui.confirm "Bundle complete! #{dependencies_count_for(definition)}, #{gems_installed_for(definition)}."
      confirm_without_groups

      if Carat.settings[:path]
        absolute_path = File.expand_path(Carat.settings[:path])
        relative_path = absolute_path.sub(File.expand_path('.'), '.')
        Carat.ui.confirm "Bundled gems are installed into #{relative_path}."
      else
        Carat.ui.confirm "Use `bundle show [gemname]` to see where a bundled gem is installed."
      end

      Installer.post_install_messages.to_a.each do |name, msg|
        Carat.ui.confirm "Post-install message from #{name}:"
        Carat.ui.info msg
      end

      Installer.ambiguous_gems.to_a.each do |name, installed_from_uri, *also_found_in_uris|
        Carat.ui.error "Warning: the gem '#{name}' was found in multiple sources."
        Carat.ui.error "Installed from: #{installed_from_uri}"
        Carat.ui.error "Also found in:"
        also_found_in_uris.each { |uri| Carat.ui.error "  * #{uri}" }
        Carat.ui.error "You should add a source requirement to restrict this gem to your preferred source."
        Carat.ui.error "For example:"
        Carat.ui.error "    gem '#{name}', :source => '#{installed_from_uri}'"
        Carat.ui.error "Then uninstall the gem '#{name}' (or delete all bundled gems) and then install again."
      end

      if Carat.settings[:clean] && Carat.settings[:path]
        require "carat/cli/clean"
        Carat::CLI::Clean.new(options).run
      end
    rescue GemNotFound, VersionConflict => e
      if options[:local] && Carat.app_cache.exist?
        Carat.ui.warn "Some gems seem to be missing from your #{Carat.settings.app_cache_path} directory."
      end

      unless Carat.definition.has_rubygems_remotes?
        Carat.ui.warn <<-WARN, :wrap => true
          Your Gemfile has no gem server sources. If you need gems that are \
          not already on your machine, add a line like this to your Gemfile:
          source 'https://rubygems.org'
        WARN
      end
      raise e
    end

  private

    def warn_if_root
      return if Carat::WINDOWS || !Process.uid.zero?
      Carat.ui.warn "Don't run Carat as root. Carat can ask for sudo " \
        "if it is needed, and installing your bundle as root will break this " \
        "application for all non-root users on this machine.", :wrap => true
    end

    def confirm_without_groups
      if Carat.settings.without.any?
        require "carat/cli/common"
        Carat.ui.confirm Carat::CLI::Common.without_groups_message
      end
    end

    def dependencies_count_for(definition)
      count = definition.dependencies.count
      "#{count} Gemfile #{count == 1 ? 'dependency' : 'dependencies'}"
    end

    def gems_installed_for(definition)
      count = definition.specs.count
      "#{count} #{count == 1 ? 'gem' : 'gems'} now installed"
    end

  end
end
