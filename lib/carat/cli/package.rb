# frozen_string_literal: true

module Carat
  class CLI::Package
    attr_reader :options

    def initialize(options)
      @options = options
    end

    def run
      Carat.ui.level = "error" if options[:quiet]
      Carat.settings.set_command_option_if_given :path, options[:path]
      Carat.settings.set_command_option_if_given :cache_all_platforms, options["all-platforms"]
      Carat.settings.set_command_option_if_given :cache_path, options["cache-path"]

      setup_cache_all
      install

      # TODO: move cache contents here now that all carats are locked
      custom_path = Carat.settings[:path] if options[:path]
      Carat.load.cache(custom_path)
    end

  private

    def install
      require "carat/cli/install"
      options = self.options.dup
      if Carat.settings[:cache_all_platforms]
        options["local"] = false
        options["update"] = true
      end
      Carat::CLI::Install.new(options).run
    end

    def setup_cache_all
      all = options.fetch(:all, Carat.feature_flag.cache_command_is_package? || nil)

      Carat.settings.set_command_option_if_given :cache_all, all

      if Carat.definition.has_local_dependencies? && !Carat.feature_flag.cache_all?
        Carat.ui.warn "Your Gemfile contains path and git dependencies. If you want "    \
          "to package them as well, please pass the --all flag. This will be the default " \
          "on Carat 2.0."
      end
    end
  end
end
