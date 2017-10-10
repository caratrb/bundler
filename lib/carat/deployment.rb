# frozen_string_literal: true

require "carat/shared_helpers"
Carat::SharedHelpers.major_deprecation 2, "Carat no longer integrates with " \
  "Capistrano, but Capistrano provides its own integration with " \
  "Carat via the capistrano-carat gem. Use it instead."

module Carat
  class Deployment
    def self.define_task(context, task_method = :task, opts = {})
      if defined?(Capistrano) && context.is_a?(Capistrano::Configuration)
        context_name = "capistrano"
        role_default = "{:except => {:no_release => true}}"
        error_type = ::Capistrano::CommandError
      else
        context_name = "vlad"
        role_default = "[:app]"
        error_type = ::Rake::CommandFailedError
      end

      roles = context.fetch(:carat_roles, false)
      opts[:roles] = roles if roles

      context.send :namespace, :carat do
        send :desc, <<-DESC
          Install the current Carat environment. By default, gems will be \
          installed to the shared/carat path. Gems in the development and \
          test group will not be installed. The install command is executed \
          with the --deployment and --quiet flags. If the carat cmd cannot \
          be found then you can override the carat_cmd variable to specify \
          which one it should use. The base path to the app is fetched from \
          the :latest_release variable. Set it for custom deploy layouts.

          You can override any of these defaults by setting the variables shown below.

          N.B. carat_roles must be defined before you require 'carat/#{context_name}' \
          in your deploy.rb file.

            set :carat_gemfile,  "Gemfile"
            set :carat_dir,      File.join(fetch(:shared_path), 'carat')
            set :carat_flags,    "--deployment --quiet"
            set :carat_without,  [:development, :test]
            set :carat_with,     [:mysql]
            set :carat_cmd,      "carat" # e.g. "/opt/ruby/bin/carat"
            set :carat_roles,    #{role_default} # e.g. [:app, :batch]
        DESC
        send task_method, :install, opts do
          carat_cmd     = context.fetch(:carat_cmd, "carat")
          carat_flags   = context.fetch(:carat_flags, "--deployment --quiet")
          carat_dir     = context.fetch(:carat_dir, File.join(context.fetch(:shared_path), "carat"))
          carat_gemfile = context.fetch(:carat_gemfile, "Gemfile")
          carat_without = [*context.fetch(:carat_without, [:development, :test])].compact
          carat_with    = [*context.fetch(:carat_with, [])].compact
          app_path = context.fetch(:latest_release)
          if app_path.to_s.empty?
            raise error_type.new("Cannot detect current release path - make sure you have deployed at least once.")
          end
          args = ["--gemfile #{File.join(app_path, carat_gemfile)}"]
          args << "--path #{carat_dir}" unless carat_dir.to_s.empty?
          args << carat_flags.to_s
          args << "--without #{carat_without.join(" ")}" unless carat_without.empty?
          args << "--with #{carat_with.join(" ")}" unless carat_with.empty?

          run "cd #{app_path} && #{carat_cmd} install #{args.join(" ")}"
        end
      end
    end
  end
end
