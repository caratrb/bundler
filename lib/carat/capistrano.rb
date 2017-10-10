# frozen_string_literal: true

require "carat/shared_helpers"
Carat::SharedHelpers.major_deprecation 2,
  "The Carat task for Capistrano. Please use http://github.com/capistrano/carat"

# Capistrano task for Carat.
#
# Add "require 'carat/capistrano'" in your Capistrano deploy.rb, and
# Carat will be activated after each new deployment.
require "carat/deployment"
require "capistrano/version"

if defined?(Capistrano::Version) && Gem::Version.new(Capistrano::Version).release >= Gem::Version.new("3.0")
  raise "For Capistrano 3.x integration, please use http://github.com/capistrano/carat"
end

Capistrano::Configuration.instance(:must_exist).load do
  before "deploy:finalize_update", "carat:install"
  Carat::Deployment.define_task(self, :task, :except => { :no_release => true })
  set :rake, lambda { "#{fetch(:carat_cmd, "carat")} exec rake" }
end
