require 'rubygems/installer'

module Carat
  class GemInstaller < Gem::Installer
    def check_executable_overwrite(filename)
      # Carat needs to install gems regardless of binstub overwriting
    end
  end
end
