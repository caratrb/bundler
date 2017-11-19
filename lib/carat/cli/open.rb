require 'carat/cli/common'
require 'shellwords'

module Carat
  class CLI::Open
    attr_reader :options, :name
    def initialize(options, name)
      @options = options
      @name = name
    end

    def run
      editor = [ENV['CARAT_EDITOR'], ENV['VISUAL'], ENV['EDITOR']].find{|e| !e.nil? && !e.empty? }
      return Carat.ui.info("To open a bundled gem, set $EDITOR or $CARAT_EDITOR") unless editor
      path = Carat::CLI::Common.select_spec(name, :regex_match).full_gem_path
      Dir.chdir(path) do
        command = Shellwords.split(editor) + [path]
        system(*command) || Carat.ui.info("Could not run '#{command.join(' ')}'")
      end
    end

  end
end
