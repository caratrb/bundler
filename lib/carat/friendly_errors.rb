# encoding: utf-8
require "cgi"
require "carat/vendored_thor"

module Carat
  def self.with_friendly_errors
    yield
  rescue Carat::CaratError => e
    Carat.ui.error e.message, :wrap => true
    Carat.ui.trace e
    exit e.status_code
  rescue Thor::AmbiguousTaskError => e
    Carat.ui.error e.message
    exit 15
  rescue Thor::UndefinedTaskError => e
    Carat.ui.error e.message
    exit 15
  rescue Thor::Error => e
    Carat.ui.error e.message
    exit 1
  rescue LoadError => e
    raise e unless e.message =~ /cannot load such file -- openssl|openssl.so|libcrypto.so/
    Carat.ui.error "\nCould not load OpenSSL."
    Carat.ui.warn <<-WARN, :wrap => true
      You must recompile Ruby with OpenSSL support or change the sources in your \
      Gemfile from 'https' to 'http'. Instructions for compiling with OpenSSL \
      using RVM are available at http://rvm.io/packages/openssl.
    WARN
    Carat.ui.trace e
    exit 1
  rescue Interrupt => e
    Carat.ui.error "\nQuitting..."
    Carat.ui.trace e
    exit 1
  rescue SystemExit => e
    exit e.status
  rescue Exception => e
    request_issue_report_for(e)
    exit 1
  end

  def self.request_issue_report_for(e)
    Carat.ui.info <<-EOS.gsub(/^ {6}/, '')
      #{'--- ERROR REPORT TEMPLATE -------------------------------------------------------'}
      - What did you do?

        I ran the command `#{$PROGRAM_NAME} #{ARGV.join(' ')}`

      - What did you expect to happen?

        I expected Carat to...

      - What happened instead?

        Instead, what actually happened was...


      Error details

          #{e.class}: #{e.message}
            #{e.backtrace.join("\n            ")}

      #{Carat::Env.new.report(:print_gemfile => false).gsub(/\n/, "\n      ").strip}
      #{'--- TEMPLATE END ----------------------------------------------------------------'}

    EOS

    Carat.ui.error "Unfortunately, an unexpected error occurred, and Carat cannot continue."

    Carat.ui.warn <<-EOS.gsub(/^ {6}/, '')

      First, try this link to see if there are any existing issue reports for this error:
      #{issues_url(e)}

      If there aren't any reports for this error yet, please create copy and paste the report template above into a new issue. Don't forget to anonymize any private data! The new issue form is located at:
      https://github.com/caratrb/carat/issues/new
    EOS
  end

  def self.issues_url(exception)
    'https://github.com/caratrb/carat/search?q=' \
    "#{CGI.escape(exception.message.lines.first.chomp)}&type=Issues"
  end

end
