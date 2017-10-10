# frozen_string_literal: true

module Carat
  # Represents metadata from when the Carat gem was built.
  module BuildMetadata
    # begin ivars
    @release = false
    # end ivars

    # A hash representation of the build metadata.
    def self.to_h
      {
        "Built At" => built_at,
        "Git SHA" => git_commit_sha,
        "Released Version" => release?,
      }
    end

    # A string representing the date the carat gem was built.
    def self.built_at
      @built_at ||= Time.now.utc.strftime("%Y-%m-%d").freeze
    end

    # The SHA for the git commit the carat gem was built from.
    def self.git_commit_sha
      @git_commit_sha ||= Dir.chdir(File.expand_path("..", __FILE__)) do
        `git rev-parse --short HEAD`.strip.freeze
      end
    end

    # Whether this is an official release build of Carat.
    def self.release?
      @release
    end
  end
end
