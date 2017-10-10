# frozen_string_literal: true

module Carat
  class CLI::Show
    attr_reader :options, :gem_name, :latest_specs
    def initialize(options, gem_name)
      @options = options
      @gem_name = gem_name
      @verbose = options[:verbose] || options[:outdated]
      @latest_specs = fetch_latest_specs if @verbose
    end

    def run
      Carat.ui.silence do
        Carat.definition.validate_runtime!
        Carat.load.lock
      end

      if gem_name
        if gem_name == "carat"
          path = File.expand_path("../../../..", __FILE__)
        else
          spec = Carat::CLI::Common.select_spec(gem_name, :regex_match)
          return unless spec
          path = spec.full_gem_path
          unless File.directory?(path)
            Carat.ui.warn "The gem #{gem_name} has been deleted. It was installed at:"
          end
        end
        return Carat.ui.info(path)
      end

      if options[:paths]
        Carat.load.specs.sort_by(&:name).map do |s|
          Carat.ui.info s.full_gem_path
        end
      else
        Carat.ui.info "Gems included by the carat:"
        Carat.load.specs.sort_by(&:name).each do |s|
          desc = "  * #{s.name} (#{s.version}#{s.git_version})"
          if @verbose
            latest = latest_specs.find {|l| l.name == s.name }
            Carat.ui.info <<-END.gsub(/^ +/, "")
              #{desc}
              \tSummary:  #{s.summary || "No description available."}
              \tHomepage: #{s.homepage || "No website available."}
              \tStatus:   #{outdated?(s, latest) ? "Outdated - #{s.version} < #{latest.version}" : "Up to date"}
            END
          else
            Carat.ui.info desc
          end
        end
      end
    end

  private

    def fetch_latest_specs
      definition = Carat.definition(true)
      if options[:outdated]
        Carat.ui.info "Fetching remote specs for outdated check...\n\n"
        Carat.ui.silence { definition.resolve_remotely! }
      else
        definition.resolve_with_cache!
      end
      Carat.reset!
      definition.specs
    end

    def outdated?(current, latest)
      return false unless latest
      Gem::Version.new(current.version) < Gem::Version.new(latest.version)
    end
  end
end
