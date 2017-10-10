# frozen_string_literal: true

module Carat
  class CLI::Check
    attr_reader :options

    def initialize(options)
      @options = options
    end

    def run
      Carat.settings.set_command_option_if_given :path, options[:path]

      begin
        definition = Carat.definition
        definition.validate_runtime!
        not_installed = definition.missing_specs
      rescue GemNotFound, VersionConflict
        Carat.ui.error "Carat can't satisfy your Gemfile's dependencies."
        Carat.ui.warn "Install missing gems with `carat install`."
        exit 1
      end

      if not_installed.any?
        Carat.ui.error "The following gems are missing"
        not_installed.each {|s| Carat.ui.error " * #{s.name} (#{s.version})" }
        Carat.ui.warn "Install missing gems with `carat install`"
        exit 1
      elsif !Carat.default_lockfile.file? && Carat.frozen?
        Carat.ui.error "This carat has been frozen, but there is no #{Carat.default_lockfile.relative_path_from(SharedHelpers.pwd)} present"
        exit 1
      else
        Carat.load.lock(:preserve_unknown_sections => true) unless options[:"dry-run"]
        Carat.ui.info "The Gemfile's dependencies are satisfied"
      end
    end
  end
end
