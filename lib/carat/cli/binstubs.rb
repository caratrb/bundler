require "carat/cli/common"

module Carat
  class CLI::Binstubs
    attr_reader :options, :gems
    def initialize(options, gems)
      @options = options
      @gems = gems
    end

    def run
      Carat.definition.validate_ruby!
      Carat.settings[:bin] = options["path"] if options["path"]
      Carat.settings[:bin] = nil if options["path"] && options["path"].empty?
      installer = Installer.new(Carat.root, Carat.definition)

      if gems.empty?
        Carat.ui.error "`carat binstubs` needs at least one gem to run."
        exit 1
      end

      gems.each do |gem_name|
        spec = installer.specs.find{|s| s.name == gem_name }
        unless spec
          raise GemNotFound, Carat::CLI::Common.gem_not_found_message(
            gem_name, Carat.definition.specs)
        end

        if spec.name == "carat"
          Carat.ui.warn "Sorry, Carat can only be run via Rubygems."
        else
          installer.generate_carat_executable_stubs(spec, :force => options[:force], :binstubs_cmd => true)
        end
      end
    end

  end
end
