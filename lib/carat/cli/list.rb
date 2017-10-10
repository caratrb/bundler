# frozen_string_literal: true

module Carat
  class CLI::List
    def initialize(options)
      @options = options
    end

    def run
      specs = Carat.load.specs.reject {|s| s.name == "carat" }.sort_by(&:name)
      return specs.each {|s| Carat.ui.info s.name } if @options["name-only"]

      return Carat.ui.info "No gems in the Gemfile" if specs.empty?
      Carat.ui.info "Gems included by the carat:"
      specs.each do |s|
        Carat.ui.info "  * #{s.name} (#{s.version}#{s.git_version})"
      end

      Carat.ui.info "Use `carat info` to print more detailed information about a gem"
    end
  end
end
