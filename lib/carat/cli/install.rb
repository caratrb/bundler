# frozen_string_literal: true

module Carat
  class CLI::Install
    attr_reader :options
    def initialize(options)
      @options = options
    end

    def run
      Carat.ui.level = "error" if options[:quiet]

      warn_if_root

      normalize_groups

      Carat::SharedHelpers.set_env "RB_USER_INSTALL", "1" if Carat::FREEBSD

      # Disable color in deployment mode
      Carat.ui.shell = Thor::Shell::Basic.new if options[:deployment]

      check_for_options_conflicts

      check_trust_policy

      if options[:deployment] || options[:frozen] || Carat.frozen?
        unless Carat.default_lockfile.exist?
          flag   = "--deployment flag" if options[:deployment]
          flag ||= "--frozen flag"     if options[:frozen]
          flag ||= "deployment setting"
          raise ProductionError, "The #{flag} requires a #{Carat.default_lockfile.relative_path_from(SharedHelpers.pwd)}. Please make " \
                                 "sure you have checked your #{Carat.default_lockfile.relative_path_from(SharedHelpers.pwd)} into version control " \
                                 "before deploying."
        end

        options[:local] = true if Carat.app_cache.exist?

        if Carat.feature_flag.deployment_means_frozen?
          Carat.settings.set_command_option :deployment, true
        else
          Carat.settings.set_command_option :frozen, true
        end
      end

      # When install is called with --no-deployment, disable deployment mode
      if options[:deployment] == false
        Carat.settings.set_command_option :frozen, nil
        options[:system] = true
      end

      normalize_settings

      Carat::Fetcher.disable_endpoint = options["full-index"]

      if options["binstubs"]
        Carat::SharedHelpers.major_deprecation 2,
          "The --binstubs option will be removed in favor of `carat binstubs`"
      end

      Plugin.gemfile_install(Carat.default_gemfile) if Carat.feature_flag.plugins?

      definition = Carat.definition
      definition.validate_runtime!

      installer = Installer.install(Carat.root, definition, options)
      Carat.load.cache if Carat.app_cache.exist? && !options["no-cache"] && !Carat.frozen?

      Carat.ui.confirm "Carat complete! #{dependencies_count_for(definition)}, #{gems_installed_for(definition)}."
      Carat::CLI::Common.output_without_groups_message

      if Carat.use_system_gems?
        Carat.ui.confirm "Use `carat info [gemname]` to see where a carated gem is installed."
      else
        relative_path = Carat.configured_carat_path.base_path_relative_to_pwd
        Carat.ui.confirm "Carat gems are installed into `#{relative_path}`"
      end

      Carat::CLI::Common.output_post_install_messages installer.post_install_messages

      warn_ambiguous_gems

      if CLI::Common.clean_after_install?
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
    rescue Gem::InvalidSpecificationException => e
      Carat.ui.warn "You have one or more invalid gemspecs that need to be fixed."
      raise e
    end

  private

    def warn_if_root
      return if Carat.settings[:silence_root_warning] || Carat::WINDOWS || !Process.uid.zero?
      Carat.ui.warn "Don't run Carat as root. Carat can ask for sudo " \
        "if it is needed, and installing your carat as root will break this " \
        "application for all non-root users on this machine.", :wrap => true
    end

    def dependencies_count_for(definition)
      count = definition.dependencies.count
      "#{count} Gemfile #{count == 1 ? "dependency" : "dependencies"}"
    end

    def gems_installed_for(definition)
      count = definition.specs.count
      "#{count} #{count == 1 ? "gem" : "gems"} now installed"
    end

    def check_for_group_conflicts_in_cli_options
      conflicting_groups = Array(options[:without]) & Array(options[:with])
      return if conflicting_groups.empty?
      raise InvalidOption, "You can't list a group in both with and without." \
        " The offending groups are: #{conflicting_groups.join(", ")}."
    end

    def check_for_options_conflicts
      if (options[:path] || options[:deployment]) && options[:system]
        error_message = String.new
        error_message << "You have specified both --path as well as --system. Please choose only one option.\n" if options[:path]
        error_message << "You have specified both --deployment as well as --system. Please choose only one option.\n" if options[:deployment]
        raise InvalidOption.new(error_message)
      end
    end

    def check_trust_policy
      trust_policy = options["trust-policy"]
      unless Carat.rubygems.security_policies.keys.unshift(nil).include?(trust_policy)
        raise InvalidOption, "RubyGems doesn't know about trust policy '#{trust_policy}'. " \
          "The known policies are: #{Carat.rubygems.security_policies.keys.join(", ")}."
      end
      Carat.settings.set_command_option_if_given :"trust-policy", trust_policy
    end

    def normalize_groups
      options[:with] &&= options[:with].join(":").tr(" ", ":").split(":")
      options[:without] &&= options[:without].join(":").tr(" ", ":").split(":")

      check_for_group_conflicts_in_cli_options

      Carat.settings.set_command_option :with, nil if options[:with] == []
      Carat.settings.set_command_option :without, nil if options[:without] == []

      with = options.fetch(:with, [])
      with |= Carat.settings[:with].map(&:to_s)
      with -= options[:without] if options[:without]

      without = options.fetch(:without, [])
      without |= Carat.settings[:without].map(&:to_s)
      without -= options[:with] if options[:with]

      options[:with]    = with
      options[:without] = without
    end

    def normalize_settings
      Carat.settings.set_command_option :path, nil if options[:system]
      Carat.settings.temporary(:path_relative_to_cwd => false) do
        Carat.settings.set_command_option :path, "vendor/carat" if options[:deployment]
      end
      Carat.settings.set_command_option_if_given :path, options[:path]
      Carat.settings.temporary(:path_relative_to_cwd => false) do
        Carat.settings.set_command_option :path, "carat" if options["standalone"] && Carat.settings[:path].nil?
      end

      bin_option = options["binstubs"]
      bin_option = nil if bin_option && bin_option.empty?
      Carat.settings.set_command_option :bin, bin_option if options["binstubs"]

      Carat.settings.set_command_option_if_given :shebang, options["shebang"]

      Carat.settings.set_command_option_if_given :jobs, options["jobs"]

      Carat.settings.set_command_option_if_given :no_prune, options["no-prune"]

      Carat.settings.set_command_option_if_given :no_install, options["no-install"]

      Carat.settings.set_command_option_if_given :clean, options["clean"]

      unless Carat.settings[:without] == options[:without] && Carat.settings[:with] == options[:with]
        # need to nil them out first to get around validation for backwards compatibility
        Carat.settings.set_command_option :without, nil
        Carat.settings.set_command_option :with,    nil
        Carat.settings.set_command_option :without, options[:without] - options[:with]
        Carat.settings.set_command_option :with,    options[:with]
      end

      options[:force] = options[:redownload]
    end

    def warn_ambiguous_gems
      Installer.ambiguous_gems.to_a.each do |name, installed_from_uri, *also_found_in_uris|
        Carat.ui.error "Warning: the gem '#{name}' was found in multiple sources."
        Carat.ui.error "Installed from: #{installed_from_uri}"
        Carat.ui.error "Also found in:"
        also_found_in_uris.each {|uri| Carat.ui.error "  * #{uri}" }
        Carat.ui.error "You should add a source requirement to restrict this gem to your preferred source."
        Carat.ui.error "For example:"
        Carat.ui.error "    gem '#{name}', :source => '#{installed_from_uri}'"
        Carat.ui.error "Then uninstall the gem '#{name}' (or delete all carated gems) and then install again."
      end
    end
  end
end
