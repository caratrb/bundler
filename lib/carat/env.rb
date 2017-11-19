require 'carat/rubygems_integration'
require 'carat/source/git/git_proxy'

module Carat
  class Env

    def write(io)
      io.write report(:print_gemfile => true)
    end

    def report(options = {})
      print_gemfile = options.delete(:print_gemfile)

      out = "Environment\n\n"
      out << "    Carat   #{Carat::VERSION}\n"
      out << "    Rubygems  #{Gem::VERSION}\n"
      out << "    Ruby      #{ruby_version}"
      out << "    GEM_HOME  #{ENV['GEM_HOME']}\n" unless ENV['GEM_HOME'].nil? || ENV['GEM_HOME'].empty?
      out << "    GEM_PATH  #{ENV['GEM_PATH']}\n" unless ENV['GEM_PATH'] == ENV['GEM_HOME']
      out << "    RVM       #{ENV['rvm_version']}\n" if ENV['rvm_version']
      out << "    Git       #{git_version}\n"
      %w(rubygems-carat open_gem).each do |name|
        specs = Carat.rubygems.find_name(name)
        out << "    #{name} (#{specs.map(&:version).join(',')})\n" unless specs.empty?
      end

      out << "\nCarat settings\n\n" unless Carat.settings.all.empty?
      Carat.settings.all.each do |setting|
        out << "    " << setting << "\n"
        Carat.settings.pretty_values_for(setting).each do |line|
          out << "      " << line << "\n"
        end
      end

      if print_gemfile
        out << "\nGemfile\n\n"
        out << "    " << read_file(Carat.default_gemfile).gsub(/\n/, "\n    ") << "\n"

        out << "\n" << "Gemfile.lock\n\n"
        out << "    " << read_file(Carat.default_lockfile).gsub(/\n/, "\n    ") << "\n"
      end

      out
    end

  private

    def read_file(filename)
      File.read(filename.to_s).strip
    rescue Errno::ENOENT
      "<No #{filename} found>"
    rescue => e
      "#{e.class}: #{e.message}"
    end

    def ruby_version
      str = "#{RUBY_VERSION}"
      if RUBY_VERSION < '1.9'
        str << " (#{RUBY_RELEASE_DATE}"
        str << " patchlevel #{RUBY_PATCHLEVEL}" if defined? RUBY_PATCHLEVEL
        str << ") [#{RUBY_PLATFORM}]\n"
      else
        str << "p#{RUBY_PATCHLEVEL}" if defined? RUBY_PATCHLEVEL
        str << " (#{RUBY_RELEASE_DATE} revision #{RUBY_REVISION}) [#{RUBY_PLATFORM}]\n"
      end
    end

    def git_version
      Carat::Source::Git::GitProxy.new(nil, nil, nil).version
    rescue Carat::Source::Git::GitNotInstalledError
      "not installed"
    end

  end
end
