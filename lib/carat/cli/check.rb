module Carat
  class CLI::Check
    attr_reader :options
    def initialize(options)
      @options = options
    end

    def run
      Carat.settings[:path] = File.expand_path(options[:path]) if options[:path]
      begin
        definition = Carat.definition
        definition.validate_ruby!
        not_installed = definition.missing_specs
      rescue GemNotFound, VersionConflict
        Carat.ui.error "Carat can't satisfy your Gemfile's dependencies."
        Carat.ui.warn  "Install missing gems with `bundle install`."
        exit 1
      end

      if not_installed.any?
        Carat.ui.error "The following gems are missing"
        not_installed.each { |s| Carat.ui.error " * #{s.name} (#{s.version})" }
        Carat.ui.warn "Install missing gems with `bundle install`"
        exit 1
      elsif !Carat.default_lockfile.exist? && Carat.settings[:frozen]
        Carat.ui.error "This bundle has been frozen, but there is no Gemfile.lock present"
        exit 1
      else
        Carat.load.lock unless options[:"dry-run"]
        Carat.ui.info "The Gemfile's dependencies are satisfied"
      end
    end

  end
end
