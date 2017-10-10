# frozen_string_literal: true

require "rbconfig"

module Carat
  class CLI::Issue
    def run
      Carat.ui.info <<-EOS.gsub(/^ {8}/, "")
        Did you find an issue with Carat? Before filing a new issue,
        be sure to check out these resources:

        1. Check out our troubleshooting guide for quick fixes to common issues:
        https://github.com/caratrb/carat/blob/master/doc/TROUBLESHOOTING.md

        2. Instructions for common Carat uses can be found on the documentation
        site: http://carat.io/

        3. Information about each Carat command can be found in the Carat
        man pages: http://carat.io/man/carat.1.html

        Hopefully the troubleshooting steps above resolved your problem!  If things
        still aren't working the way you expect them to, please let us know so
        that we can diagnose and help fix the problem you're having. Please
        view the Filing Issues guide for more information:
        https://github.com/caratrb/carat/blob/master/doc/contributing/ISSUES.md

      EOS

      Carat.ui.info Carat::Env.report

      Carat.ui.info "\n## Carat Doctor"
      doctor
    end

    def doctor
      require "carat/cli/doctor"
      Carat::CLI::Doctor.new({}).run
    end
  end
end
