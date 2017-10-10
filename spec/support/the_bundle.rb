# frozen_string_literal: true

require "support/helpers"
require "support/path"

module Spec
  class TheCarat
    include Spec::Helpers
    include Spec::Path

    attr_accessor :carat_dir

    def initialize(opts = {})
      opts = opts.dup
      @carat_dir = Pathname.new(opts.delete(:carat_dir) { carated_app })
      raise "Too many options! #{opts}" unless opts.empty?
    end

    def to_s
      "the carat"
    end
    alias_method :inspect, :to_s

    def locked?
      lockfile.file?
    end

    def lockfile
      carat_dir.join("Gemfile.lock")
    end

    def locked_gems
      raise "Cannot read lockfile if it doesn't exist" unless locked?
      Carat::LockfileParser.new(lockfile.read)
    end
  end
end
