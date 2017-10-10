# frozen_string_literal: true

module Carat
  class CLI::Init
    attr_reader :options
    def initialize(options)
      @options = options
    end

    def run
      if File.exist?(gemfile)
        Carat.ui.error "#{gemfile} already exists at #{File.expand_path(gemfile)}"
        exit 1
      end

      if options[:gemspec]
        gemspec = File.expand_path(options[:gemspec])
        unless File.exist?(gemspec)
          Carat.ui.error "Gem specification #{gemspec} doesn't exist"
          exit 1
        end

        spec = Carat.load_gemspec_uncached(gemspec)

        File.open(gemfile, "wb") do |file|
          file << "# Generated from #{gemspec}\n"
          file << spec.to_gemfile
        end
      else
        FileUtils.cp(File.expand_path("../../templates/#{gemfile}", __FILE__), gemfile)
      end

      puts "Writing new #{gemfile} to #{SharedHelpers.pwd}/#{gemfile}"
    end

  private

    def gemfile
      @gemfile ||= begin
        Carat.default_gemfile
      rescue GemfileNotFound
        Carat.feature_flag.init_gems_rb? ? "gems.rb" : "Gemfile"
      end
    end
  end
end
