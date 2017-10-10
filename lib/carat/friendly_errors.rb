# encoding: utf-8
# frozen_string_literal: true

require "cgi"
require "carat/vendored_thor"

module Carat
  module FriendlyErrors
  module_function

    def log_error(error)
      case error
      when YamlSyntaxError
        Carat.ui.error error.message
        Carat.ui.trace error.orig_exception
      when Dsl::DSLError, GemspecError
        Carat.ui.error error.message
      when GemRequireError
        Carat.ui.error error.message
        Carat.ui.trace error.orig_exception, nil, true
      when CaratError
        Carat.ui.error error.message, :wrap => true
        Carat.ui.trace error
      when Thor::Error
        Carat.ui.error error.message
      when LoadError
        raise error unless error.message =~ /cannot load such file -- openssl|openssl.so|libcrypto.so/
        Carat.ui.error "\nCould not load OpenSSL."
        Carat.ui.warn <<-WARN, :wrap => true
          You must recompile Ruby with OpenSSL support or change the sources in your \
          Gemfile from 'https' to 'http'. Instructions for compiling with OpenSSL \
          using RVM are available at http://rvm.io/packages/openssl.
        WARN
        Carat.ui.trace error
      when Interrupt
        Carat.ui.error "\nQuitting..."
        Carat.ui.trace error
      when Gem::InvalidSpecificationException
        Carat.ui.error error.message, :wrap => true
      when SystemExit
      when *[defined?(Java::JavaLang::OutOfMemoryError) && Java::JavaLang::OutOfMemoryError].compact
        Carat.ui.error "\nYour JVM has run out of memory, and Carat cannot continue. " \
          "You can decrease the amount of memory Carat needs by removing gems from your Gemfile, " \
          "especially large gems. (Gems can be as large as hundreds of megabytes, and Carat has to read those files!). " \
          "Alternatively, you can increase the amount of memory the JVM is able to use by running Carat with jruby -J-Xmx1024m -S carat (JRuby defaults to 500MB)."
      else request_issue_report_for(error)
      end
    end

    def exit_status(error)
      case error
      when CaratError then error.status_code
      when Thor::Error then 15
      when SystemExit then error.status
      else 1
      end
    end

    def request_issue_report_for(e)
      Carat.ui.info <<-EOS.gsub(/^ {8}/, "")
        --- ERROR REPORT TEMPLATE -------------------------------------------------------
        # Error Report

        ## Questions

        Please fill out answers to these questions, it'll help us figure out
        why things are going wrong.

        - **What did you do?**

          I ran the command `#{$PROGRAM_NAME} #{ARGV.join(" ")}`

        - **What did you expect to happen?**

          I expected Carat to...

        - **What happened instead?**

          Instead, what happened was...

        - **Have you tried any solutions posted on similar issues in our issue tracker, stack overflow, or google?**

          I tried...

        - **Have you read our issues document, https://github.com/caratrb/carat/blob/master/doc/contributing/ISSUES.md?**

          ...

        ## Backtrace

        ```
        #{e.class}: #{e.message}
          #{e.backtrace && e.backtrace.join("\n          ").chomp}
        ```

        #{Carat::Env.report}
        --- TEMPLATE END ----------------------------------------------------------------

      EOS

      Carat.ui.error "Unfortunately, an unexpected error occurred, and Carat cannot continue."

      Carat.ui.warn <<-EOS.gsub(/^ {8}/, "")

        First, try this link to see if there are any existing issue reports for this error:
        #{issues_url(e)}

        If there aren't any reports for this error yet, please create copy and paste the report template above into a new issue. Don't forget to anonymize any private data! The new issue form is located at:
        https://github.com/caratrb/carat/issues/new
      EOS
    end

    def issues_url(exception)
      message = exception.message.lines.first.tr(":", " ").chomp
      message = message.split("-").first if exception.is_a?(Errno)
      "https://github.com/caratrb/carat/search?q=" \
        "#{CGI.escape(message)}&type=Issues"
    end
  end

  def self.with_friendly_errors
    yield
  rescue Exception => e
    FriendlyErrors.log_error(e)
    exit FriendlyErrors.exit_status(e)
  end
end
