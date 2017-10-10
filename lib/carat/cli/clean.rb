# frozen_string_literal: true

module Carat
  class CLI::Clean
    attr_reader :options

    def initialize(options)
      @options = options
    end

    def run
      require_path_or_force unless options[:"dry-run"]
      Carat.load.clean(options[:"dry-run"])
    end

  protected

    def require_path_or_force
      return unless Carat.use_system_gems? && !options[:force]
      raise InvalidOption, "Cleaning all the gems on your system is dangerous! " \
        "If you're sure you want to remove every system gem not in this " \
        "carat, run `carat clean --force`."
    end
  end
end
