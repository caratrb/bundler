# frozen_string_literal: true

module Carat
  class CLI::Binstubs
    attr_reader :options, :gems
    def initialize(options, gems)
      @options = options
      @gems = gems
    end

    def run
      Carat.definition.validate_runtime!
      path_option = options["path"]
      path_option = nil if path_option && path_option.empty?
      Carat.settings.set_command_option :bin, path_option if options["path"]
      Carat.settings.set_command_option_if_given :shebang, options["shebang"]
      installer = Installer.new(Carat.root, Carat.definition)

      if gems.empty?
        Carat.ui.error "`carat binstubs` needs at least one gem to run."
        exit 1
      end

      gems.each do |gem_name|
        spec = Carat.definition.specs.find {|s| s.name == gem_name }
        unless spec
          raise GemNotFound, Carat::CLI::Common.gem_not_found_message(
            gem_name, Carat.definition.specs
          )
        end

        if options[:standalone]
          next Carat.ui.warn("Sorry, Carat can only be run via RubyGems.") if gem_name == "carat"
          Carat.settings.temporary(:path => (Carat.settings[:path] || Carat.root)) do
            installer.generate_standalone_carat_executable_stubs(spec)
          end
        else
          installer.generate_carat_executable_stubs(spec, :force => options[:force], :binstubs_cmd => true)
        end
      end
    end
  end
end
