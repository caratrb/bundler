module Carat
  class CLI::Package
    attr_reader :options

    def initialize(options)
      @options = options
    end

    def run
      Carat.ui.level = "error" if options[:quiet]
      Carat.settings[:path] = File.expand_path(options[:path]) if options[:path]
      Carat.settings[:cache_all_platforms] = options["all-platforms"] if options.key?("all-platforms")
      Carat.settings[:cache_path] = options["cache-path"] if options.key?("cache-path")

      setup_cache_all
      install

      # TODO: move cache contents here now that all bundles are locked
      custom_path = Pathname.new(options[:path]) if options[:path]
      Carat.load.cache(custom_path)
    end

  private

    def install
      require 'carat/cli/install'
      options = self.options.dup
      if Carat.settings[:cache_all_platforms]
        options["local"] = false
        options["update"] = true
      end
      Carat::CLI::Install.new(options).run
    end

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
