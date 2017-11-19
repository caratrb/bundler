module Carat
  class CLI::Update
    attr_reader :options, :gems
    def initialize(options, gems)
      @options = options
      @gems = gems
    end

    def run
      Carat.ui.level = "error" if options[:quiet]

      sources = Array(options[:source])
      groups  = Array(options[:group]).map(&:to_sym)

      if gems.empty? && sources.empty? && groups.empty?
        # We're doing a full update
        Carat.definition(true)
      else
        unless Carat.default_lockfile.exist?
          raise GemfileLockNotFound, "This Bundle hasn't been installed yet. " \
            "Run `carat install` to update and install the bundled gems."
        end
        # cycle through the requested gems, just to make sure they exist
        names = Carat.locked_gems.specs.map{ |s| s.name }
        gems.each do |g|
          next if names.include?(g)
          require "carat/cli/common"
          raise GemNotFound, Carat::CLI::Common.gem_not_found_message(g, names)
        end

        if groups.any?
          specs = Carat.definition.specs_for groups
          sources.concat(specs.map(&:name))
        end

        Carat.definition(:gems => gems, :sources => sources)
      end

      Carat::Fetcher.disable_endpoint = options["full-index"]

      opts = options.dup
      opts["update"] = true
      opts["local"] = options[:local]

      Carat.settings[:jobs] = opts["jobs"] if opts["jobs"]

      # rubygems plugins sometimes hook into the gem install process
      Gem.load_env_plugins if Gem.respond_to?(:load_env_plugins)

      Carat.definition.validate_ruby!
      Installer.install Carat.root, Carat.definition, opts
      Carat.load.cache if Carat.app_cache.exist?

      if Carat.settings[:clean] && Carat.settings[:path]
        require "carat/cli/clean"
        Carat::CLI::Clean.new(options).run
      end

      Carat.ui.confirm "Bundle updated!"
      without_groups_messages
    end

  private

    def without_groups_messages
      if Carat.settings.without.any?
        require "carat/cli/common"
        Carat.ui.confirm Carat::CLI::Common.without_groups_message
      end
    end

  end
end
