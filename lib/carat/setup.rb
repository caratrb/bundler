require 'carat/shared_helpers'

if Carat::SharedHelpers.in_bundle?
  require 'carat'

  if STDOUT.tty? || ENV['CARAT_FORCE_TTY']
    begin
      Carat.setup
    rescue Carat::CaratError => e
      puts "\e[31m#{e.message}\e[0m"
      puts e.backtrace.join("\n") if ENV["DEBUG"]
      if e.is_a?(Carat::GemNotFound)
        puts "\e[33mRun `bundle install` to install missing gems.\e[0m"
      end
      exit e.status_code
    end
  else
    Carat.setup
  end

  # Add carat to the load path after disabling system gems
  carat_lib = File.expand_path("../..", __FILE__)
  $LOAD_PATH.unshift(carat_lib) unless $LOAD_PATH.include?(carat_lib)
end
