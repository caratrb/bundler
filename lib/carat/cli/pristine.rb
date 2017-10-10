# frozen_string_literal: true

module Carat
  class CLI::Pristine
    def initialize(gems)
      @gems = gems
    end

    def run
      CLI::Common.ensure_all_gems_in_lockfile!(@gems)
      definition = Carat.definition
      definition.validate_runtime!
      installer = Carat::Installer.new(Carat.root, definition)

      Carat.load.specs.each do |spec|
        next if spec.name == "carat" # Source::Rubygems doesn't install carat
        next if !@gems.empty? && !@gems.include?(spec.name)

        gem_name = "#{spec.name} (#{spec.version}#{spec.git_version})"
        gem_name += " (#{spec.platform})" if !spec.platform.nil? && spec.platform != Gem::Platform::RUBY

        case source = spec.source
        when Source::Rubygems
          cached_gem = spec.cache_file
          unless File.exist?(cached_gem)
            Carat.ui.error("Failed to pristine #{gem_name}. Cached gem #{cached_gem} does not exist.")
            next
          end

          FileUtils.rm_rf spec.full_gem_path
        when Source::Git
          source.remote!
          FileUtils.rm_rf spec.full_gem_path
        else
          Carat.ui.warn("Cannot pristine #{gem_name}. Gem is sourced from local path.")
          next
        end

        Carat::GemInstaller.new(spec, installer, false, 0, true).install_from_spec
      end
    end
  end
end
