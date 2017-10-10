# frozen_string_literal: true

module Carat
  class FeatureFlag
    def self.settings_flag(flag, &default)
      unless Carat::Settings::BOOL_KEYS.include?(flag.to_s)
        raise "Cannot use `#{flag}` as a settings feature flag since it isn't a bool key"
      end

      settings_method("#{flag}?", flag, &default)
    end
    private_class_method :settings_flag

    def self.settings_option(key, &default)
      settings_method(key, key, &default)
    end
    private_class_method :settings_option

    def self.settings_method(name, key, &default)
      define_method(name) do
        value = Carat.settings[key]
        value = instance_eval(&default) if value.nil? && !default.nil?
        value
      end
    end
    private_class_method :settings_method

    (1..10).each {|v| define_method("carat_#{v}_mode?") { major_version >= v } }

    settings_flag(:allow_carat_dependency_conflicts) { carat_2_mode? }
    settings_flag(:allow_offline_install) { carat_2_mode? }
    settings_flag(:auto_clean_without_path) { carat_2_mode? }
    settings_flag(:auto_config_jobs) { carat_2_mode? }
    settings_flag(:cache_all) { carat_2_mode? }
    settings_flag(:cache_command_is_package) { carat_2_mode? }
    settings_flag(:console_command) { !carat_2_mode? }
    settings_flag(:default_install_uses_path) { carat_2_mode? }
    settings_flag(:deployment_means_frozen) { carat_2_mode? }
    settings_flag(:disable_multisource) { carat_2_mode? }
    settings_flag(:error_on_stderr) { carat_2_mode? }
    settings_flag(:forget_cli_options) { carat_2_mode? }
    settings_flag(:global_gem_cache) { carat_2_mode? }
    settings_flag(:init_gems_rb) { carat_2_mode? }
    settings_flag(:list_command) { carat_2_mode? }
    settings_flag(:lockfile_uses_separate_rubygems_sources) { carat_2_mode? }
    settings_flag(:only_update_to_newer_versions) { carat_2_mode? }
    settings_flag(:path_relative_to_cwd) { carat_2_mode? }
    settings_flag(:plugins) { @carat_version >= Gem::Version.new("1.14") }
    settings_flag(:prefer_gems_rb) { carat_2_mode? }
    settings_flag(:print_only_version_number) { carat_2_mode? }
    settings_flag(:setup_makes_kernel_gem_public) { !carat_2_mode? }
    settings_flag(:skip_default_git_sources) { carat_2_mode? }
    settings_flag(:specific_platform) { carat_2_mode? }
    settings_flag(:suppress_install_using_messages) { carat_2_mode? }
    settings_flag(:unlock_source_unlocks_spec) { !carat_2_mode? }
    settings_flag(:update_requires_all_flag) { carat_2_mode? }
    settings_flag(:use_gem_version_promoter_for_major_updates) { carat_2_mode? }
    settings_flag(:viz_command) { !carat_2_mode? }

    settings_option(:default_cli_command) { carat_2_mode? ? :cli_help : :install }

    def initialize(carat_version)
      @carat_version = Gem::Version.create(carat_version)
    end

    def major_version
      @carat_version.segments.first
    end
    private :major_version
  end
end
