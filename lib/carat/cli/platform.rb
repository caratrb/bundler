module Carat
  class CLI::Platform
    attr_reader :options
    def initialize(options)
      @options = options
    end

    def run
      platforms, ruby_version = Carat.ui.silence do
        [ Carat.definition.platforms.map {|p| "* #{p}" },
          Carat.definition.ruby_version ]
      end
      output = []

      if options[:ruby]
        if ruby_version
          output << ruby_version
        else
          output << "No ruby version specified"
        end
      else
        output << "Your platform is: #{RUBY_PLATFORM}"
        output << "Your app has gems that work on these platforms:\n#{platforms.join("\n")}"

        if ruby_version
          output << "Your Gemfile specifies a Ruby version requirement:\n* #{ruby_version}"

          begin
            Carat.definition.validate_ruby!
            output << "Your current platform satisfies the Ruby version requirement."
          rescue RubyVersionMismatch => e
            output << e.message
          end
        else
          output << "Your Gemfile does not specify a Ruby version requirement."
        end
      end

      Carat.ui.info output.join("\n\n")
    end

  end
end
