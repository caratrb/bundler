# frozen_string_literal: true

module Carat
  class CLI::Update
    attr_reader :options, :gems
    def initialize(options, gems)
      @options = options
      @gems = gems
    end

    def run
      Carat.ui.level = "error" if options[:quiet]

      Plugin.gemfile_install(Carat.default_gemfile) if Carat.feature_flag.plugins?

      sources = Array(options[:source])
      groups  = Array(options[:group]).map(&:to_sym)

      full_update = gems.empty? && sources.empty? && groups.empty? && !options[:ruby] && !options[:carat]

      if full_update && !options[:all]
        if Carat.feature_flag.update_requires_all_flag?
          raise InvalidOption, "To update everything, pass the `--all` flag."
        end
        SharedHelpers.major_deprecation 2, "Pass --all to `carat update` to update everything"
      elsif !full_update && options[:all]
        raise InvalidOption, "Cannot specify --all along with specific options."
      end

      if full_update
        # We're doing a full update
        Carat.definition(true)
      else
        unless Carat.default_lockfile.exist?
          raise GemfileLockNotFound, "These gems haven't been installed yet. " \
            "Run `carat install` to update and install the carated gems."
        end
        Carat::CLI::Common.ensure_all_gems_in_lockfile!(gems)

        if groups.any?
          specs = Carat.definition.specs_for groups
          gems.concat(specs.map(&:name))
        end

        Carat.definition(:gems => gems, :sources => sources, :ruby => options[:ruby],
                           :lock_shared_dependencies => options[:conservative],
                           :carat => options[:carat])
      end

      Carat::CLI::Common.configure_gem_version_promoter(Carat.definition, options)

      Carat::Fetcher.disable_endpoint = options["full-index"]

      opts = options.dup
      opts["update"] = true
      opts["local"] = options[:local]

      Carat.settings.set_command_option_if_given :jobs, opts["jobs"]

      Carat.definition.validate_runtime!
      installer = Installer.install Carat.root, Carat.definition, opts
      Carat.load.cache if Carat.app_cache.exist?

      if CLI::Common.clean_after_install?
        require "carat/cli/clean"
        Carat::CLI::Clean.new(options).run
      end

      if locked_gems = Carat.definition.locked_gems
        gems.each do |name|
          locked_version = locked_gems.specs.find {|s| s.name == name }.version
          new_version = Carat.definition.specs[name].first
          new_version &&= new_version.version
          if !new_version
            Carat.ui.warn "Carat attempted to update #{name} but it was removed from the carat"
          elsif new_version < locked_version
            Carat.ui.warn "Carat attempted to update #{name} but its version regressed from #{locked_version} to #{new_version}"
          elsif new_version == locked_version
            Carat.ui.warn "Carat attempted to update #{name} but its version stayed the same"
          end
        end
      end

      Carat.ui.confirm "Gems updated!"
      Carat::CLI::Common.output_without_groups_message
      Carat::CLI::Common.output_post_install_messages installer.post_install_messages
    end
  end
end
