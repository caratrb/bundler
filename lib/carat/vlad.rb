# Vlad task for Bundler.
#
# Just add "require 'carat/vlad'" in your Vlad deploy.rb, and
# include the vlad:bundle:install task in your vlad:deploy task.
require 'carat/deployment'

include Rake::DSL if defined? Rake::DSL

namespace :vlad do
  Bundler::Deployment.define_task(Rake::RemoteTask, :remote_task, :roles => :app)
end
