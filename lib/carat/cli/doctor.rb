# frozen_string_literal: true

require "rbconfig"

module Carat
  class CLI::Doctor
    DARWIN_REGEX = /\s+(.+) \(compatibility /
    LDD_REGEX = /\t\S+ => (\S+) \(\S+\)/

    attr_reader :options

    def initialize(options)
      @options = options
    end

    def otool_available?
      Carat.which("otool")
    end

    def ldd_available?
      Carat.which("ldd")
    end

    def dylibs_darwin(path)
      output = `/usr/bin/otool -L "#{path}"`.chomp
      dylibs = output.split("\n")[1..-1].map {|l| l.match(DARWIN_REGEX).captures[0] }.uniq
      # ignore @rpath and friends
      dylibs.reject {|dylib| dylib.start_with? "@" }
    end

    def dylibs_ldd(path)
      output = `/usr/bin/ldd "#{path}"`.chomp
      output.split("\n").map do |l|
        match = l.match(LDD_REGEX)
        next if match.nil?
        match.captures[0]
      end.compact
    end

    def dylibs(path)
      case RbConfig::CONFIG["host_os"]
      when /darwin/
        return [] unless otool_available?
        dylibs_darwin(path)
      when /(linux|solaris|bsd)/
        return [] unless ldd_available?
        dylibs_ldd(path)
      else # Windows, etc.
        Carat.ui.warn("Dynamic library check not supported on this platform.")
        []
      end
    end

    def carats_for_gem(spec)
      Dir.glob("#{spec.full_gem_path}/**/*.carat")
    end

    def check!
      require "carat/cli/check"
      Carat::CLI::Check.new({}).run
    end

    def run
      Carat.ui.level = "error" if options[:quiet]
      Carat.settings.validate!
      check!

      definition = Carat.definition
      broken_links = {}

      definition.specs.each do |spec|
        carats_for_gem(spec).each do |carat|
          bad_paths = dylibs(carat).select {|f| !File.exist?(f) }
          if bad_paths.any?
            broken_links[spec] ||= []
            broken_links[spec].concat(bad_paths)
          end
        end
      end

      if broken_links.any?
        message = "The following gems are missing OS dependencies:"
        broken_links.map do |spec, paths|
          paths.uniq.map do |path|
            "\n * #{spec.name}: #{path}"
          end
        end.flatten.sort.each {|m| message += m }
        raise ProductionError, message
      else
        Carat.ui.info "No issues found with the installed carat"
      end
    end
  end
end
