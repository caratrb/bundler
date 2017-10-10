# frozen_string_literal: true

module Carat
  class CLI::Lock
    attr_reader :options

    def initialize(options)
      @options = options
    end

    def run
      unless Carat.default_gemfile
        Carat.ui.error "Unable to find a Gemfile to lock"
        exit 1
      end

      print = options[:print]
      ui = Carat.ui
      Carat.ui = UI::Silent.new if print

      Carat::Fetcher.disable_endpoint = options["full-index"]

      update = options[:update]
      if update.is_a?(Array) # unlocking specific gems
        Carat::CLI::Common.ensure_all_gems_in_lockfile!(update)
        update = { :gems => update, :lock_shared_dependencies => options[:conservative] }
      end
      definition = Carat.definition(update)

      Carat::CLI::Common.configure_gem_version_promoter(Carat.definition, options) if options[:update]

      options["remove-platform"].each do |platform|
        definition.remove_platform(platform)
      end

      options["add-platform"].each do |platform_string|
        platform = Gem::Platform.new(platform_string)
        if platform.to_s == "unknown"
          Carat.ui.warn "The platform `#{platform_string}` is unknown to RubyGems " \
            "and adding it will likely lead to resolution errors"
        end
        definition.add_platform(platform)
      end

      if definition.platforms.empty?
        raise InvalidOption, "Removing all platforms from the carat is not allowed"
      end

      definition.resolve_remotely! unless options[:local]

      if print
        puts definition.to_lock
      else
        file = options[:lockfile]
        file = file ? File.expand_path(file) : Carat.default_lockfile
        puts "Writing lockfile to #{file}"
        definition.lock(file)
      end

      Carat.ui = ui
    end
  end
end
