# frozen_string_literal: true

require "shellwords"

module Carat
  class CLI::Open
    attr_reader :options, :name
    def initialize(options, name)
      @options = options
      @name = name
    end

    def run
      editor = [ENV["CARAT_EDITOR"], ENV["VISUAL"], ENV["EDITOR"]].find {|e| !e.nil? && !e.empty? }
      return Carat.ui.info("To open a carated gem, set $EDITOR or $CARAT_EDITOR") unless editor
      return unless spec = Carat::CLI::Common.select_spec(name, :regex_match)
      path = spec.full_gem_path
      Dir.chdir(path) do
        command = Shellwords.split(editor) + [path]
        Carat.with_original_env do
          system(*command)
        end || Carat.ui.info("Could not run '#{command.join(" ")}'")
      end
    end
  end
end
