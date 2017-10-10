# frozen_string_literal: true

module Carat
  class CLI::Cache
    attr_reader :options
    def initialize(options)
      @options = options
    end

    def run
      Carat.definition.validate_runtime!
      Carat.definition.resolve_with_cache!
      setup_cache_all
      Carat.settings.set_command_option_if_given :cache_all_platforms, options["all-platforms"]
      Carat.load.cache
      Carat.settings.set_command_option_if_given :no_prune, options["no-prune"]
      Carat.load.lock
    rescue GemNotFound => e
      Carat.ui.error(e.message)
      Carat.ui.warn "Run `carat install` to install missing gems."
      exit 1
    end

  private

    def setup_cache_all
      Carat.settings.set_command_option_if_given :cache_all, options[:all]

      if Carat.definition.has_local_dependencies? && !Carat.feature_flag.cache_all?
        Carat.ui.warn "Your Gemfile contains path and git dependencies. If you want "    \
          "to package them as well, please pass the --all flag. This will be the default " \
          "on Carat 2.0."
      end
    end
  end
end
