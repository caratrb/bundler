# frozen_string_literal: true

require "carat/compatibility_guard"

# Allows for declaring a Gemfile inline in a ruby script, optionally installing
# any gems that aren't already installed on the user's system.
#
# @note Every gem that is specified in this 'Gemfile' will be `require`d, as if
#       the user had manually called `Carat.require`. To avoid a requested gem
#       being automatically required, add the `:require => false` option to the
#       `gem` dependency declaration.
#
# @param install [Boolean] whether gems that aren't already installed on the
#                          user's system should be installed.
#                          Defaults to `false`.
#
# @param gemfile [Proc]    a block that is evaluated as a `Gemfile`.
#
# @example Using an inline Gemfile
#
#          #!/usr/bin/env ruby
#
#          require 'carat/inline'
#
#          gemfile do
#            source 'https://rubygems.org'
#            gem 'json', require: false
#            gem 'nap', require: 'rest'
#            gem 'cocoapods', '~> 0.34.1'
#          end
#
#          puts Pod::VERSION # => "0.34.4"
#
def gemfile(install = false, options = {}, &gemfile)
  require "carat"

  opts = options.dup
  ui = opts.delete(:ui) { Carat::UI::Shell.new }
  raise ArgumentError, "Unknown options: #{opts.keys.join(", ")}" unless opts.empty?

  old_root = Carat.method(:root)
  def Carat.root
    Carat::SharedHelpers.pwd.expand_path
  end
  Carat::SharedHelpers.set_env "CARAT_GEMFILE", "Gemfile"

  Carat::Plugin.gemfile_install(&gemfile) if Carat.feature_flag.plugins?
  builder = Carat::Dsl.new
  builder.instance_eval(&gemfile)

  definition = builder.to_definition(nil, true)
  def definition.lock(*); end
  definition.validate_runtime!

  missing_specs = proc do
    definition.missing_specs?
  end

  Carat.ui = ui if install
  if install || missing_specs.call
    Carat.settings.temporary(:inline => true) do
      installer = Carat::Installer.install(Carat.root, definition, :system => true)
      installer.post_install_messages.each do |name, message|
        Carat.ui.info "Post-install message from #{name}:\n#{message}"
      end
    end
  end

  runtime = Carat::Runtime.new(nil, definition)
  runtime.setup.require
ensure
  carat_module = class << Carat; self; end
  carat_module.send(:define_method, :root, old_root) if old_root
end
