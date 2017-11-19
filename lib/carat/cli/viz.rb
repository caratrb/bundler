module Carat
  class CLI::Viz
    attr_reader :options, :gem_name
    def initialize(options)
      @options = options
    end

    def run
      require 'graphviz'
      output_file = File.expand_path(options[:file])
      graph = Graph.new(Carat.load, output_file, options[:version], options[:requirements], options[:format], options[:without])
      graph.viz
    rescue LoadError => e
      Carat.ui.error e.inspect
      Carat.ui.warn "Make sure you have the graphviz ruby gem. You can install it with:"
      Carat.ui.warn "`gem install ruby-graphviz`"
    rescue StandardError => e
      if e.message =~ /GraphViz not installed or dot not in PATH/
        Carat.ui.error e.message
        Carat.ui.warn "Please install GraphViz. On a Mac with homebrew, you can run `brew install graphviz`."
      else
        raise
      end
    end

  end
end
