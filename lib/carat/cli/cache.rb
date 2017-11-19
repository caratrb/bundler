module Carat
  class CLI::Cache
    attr_reader :options
    def initialize(options)
      @options = options
    end

    def run
      Carat.definition.validate_ruby!
      Carat.definition.resolve_with_cache!
      setup_cache_all
      Carat.settings[:cache_all_platforms] = options["all-platforms"] if options.key?("all-platforms")
      Carat.load.cache
      Carat.settings[:no_prune] = true if options["no-prune"]
      Carat.load.lock
    rescue GemNotFound => e
      Carat.ui.error(e.message)
      Carat.ui.warn "Run `bundle install` to install missing gems."
      exit 1
    end

  private

    def setup_cache_all
      Carat.settings[:cache_all] = options[:all] if options.key?("all")

      if Carat.definition.has_local_dependencies? && !Carat.settings[:cache_all]
        Carat.ui.warn "Your Gemfile contains path and git dependencies. If you want "    \
          "to package them as well, please pass the --all flag. This will be the default " \
          "on Carat 2.0."
      end
    end

  end
end
