# frozen_string_literal: true

module Carat
  WINDOWS = RbConfig::CONFIG["host_os"] =~ /(msdos|mswin|djgpp|mingw)/
  FREEBSD = RbConfig::CONFIG["host_os"] =~ /bsd/
  NULL    = WINDOWS ? "NUL" : "/dev/null"
end
