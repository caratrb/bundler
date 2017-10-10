# frozen_string_literal: true

require "carat/shared_helpers"
Carat::SharedHelpers.major_deprecation 2,
  "The Carat task for Vlad"

# Vlad task for Carat.
#
# Add "require 'carat/vlad'" in your Vlad deploy.rb, and
# include the vlad:carat:install task in your vlad:deploy task.
require "carat/deployment"

include Rake::DSL if defined? Rake::DSL

namespace :vlad do
  Carat::Deployment.define_task(Rake::RemoteTask, :remote_task, :roles => :app)
end
