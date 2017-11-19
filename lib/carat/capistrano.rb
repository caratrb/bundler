# Capistrano task for Carat.
#
# Just add "require 'carat/capistrano'" in your Capistrano deploy.rb, and
# Carat will be activated after each new deployment.
require 'carat/deployment'
require 'capistrano/version'

if defined?(Capistrano::Version) && Gem::Version.new(Capistrano::Version).release >= Gem::Version.new("3.0")
  raise "For Capistrano 3.x integration, please use http://github.com/capistrano/bundler"
end

Capistrano::Configuration.instance(:must_exist).load do
  before "deploy:finalize_update", "bundle:install"
  Carat::Deployment.define_task(self, :task, :except => { :no_release => true })
  set :rake, lambda { "#{fetch(:bundle_cmd, "bundle")} exec rake" }
end
