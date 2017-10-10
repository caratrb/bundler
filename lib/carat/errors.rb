# frozen_string_literal: true

module Carat
  class CaratError < StandardError
    def self.status_code(code)
      define_method(:status_code) { code }
      if match = CaratError.all_errors.find {|_k, v| v == code }
        error, _ = match
        raise ArgumentError,
          "Trying to register #{self} for status code #{code} but #{error} is already registered"
      end
      CaratError.all_errors[self] = code
    end

    def self.all_errors
      @all_errors ||= {}
    end
  end

  class GemfileError < CaratError; status_code(4); end
  class InstallError < CaratError; status_code(5); end

  # Internal error, should be rescued
  class VersionConflict < CaratError
    attr_reader :conflicts

    def initialize(conflicts, msg = nil)
      super(msg)
      @conflicts = conflicts
    end

    status_code(6)
  end

  class GemNotFound < CaratError; status_code(7); end
  class InstallHookError < CaratError; status_code(8); end
  class GemfileNotFound < CaratError; status_code(10); end
  class GitError < CaratError; status_code(11); end
  class DeprecatedError < CaratError; status_code(12); end
  class PathError < CaratError; status_code(13); end
  class GemspecError < CaratError; status_code(14); end
  class InvalidOption < CaratError; status_code(15); end
  class ProductionError < CaratError; status_code(16); end
  class HTTPError < CaratError
    status_code(17)
    def filter_uri(uri)
      URICredentialsFilter.credential_filtered_uri(uri)
    end
  end
  class RubyVersionMismatch < CaratError; status_code(18); end
  class SecurityError < CaratError; status_code(19); end
  class LockfileError < CaratError; status_code(20); end
  class CyclicDependencyError < CaratError; status_code(21); end
  class GemfileLockNotFound < CaratError; status_code(22); end
  class PluginError < CaratError; status_code(29); end
  class SudoNotPermittedError < CaratError; status_code(30); end
  class ThreadCreationError < CaratError; status_code(33); end
  class APIResponseMismatchError < CaratError; status_code(34); end
  class GemfileEvalError < GemfileError; end
  class MarshalError < StandardError; end

  class PermissionError < CaratError
    def initialize(path, permission_type = :write)
      @path = path
      @permission_type = permission_type
    end

    def action
      case @permission_type
      when :read then "read from"
      when :write then "write to"
      when :executable, :exec then "execute"
      else @permission_type.to_s
      end
    end

    def message
      "There was an error while trying to #{action} `#{@path}`. " \
      "It is likely that you need to grant #{@permission_type} permissions " \
      "for that path."
    end

    status_code(23)
  end

  class GemRequireError < CaratError
    attr_reader :orig_exception

    def initialize(orig_exception, msg)
      full_message = msg + "\nGem Load Error is: #{orig_exception.message}\n"\
                      "Backtrace for gem load error is:\n"\
                      "#{orig_exception.backtrace.join("\n")}\n"\
                      "Carat Error Backtrace:\n"
      super(full_message)
      @orig_exception = orig_exception
    end

    status_code(24)
  end

  class YamlSyntaxError < CaratError
    attr_reader :orig_exception

    def initialize(orig_exception, msg)
      super(msg)
      @orig_exception = orig_exception
    end

    status_code(25)
  end

  class TemporaryResourceError < PermissionError
    def message
      "There was an error while trying to #{action} `#{@path}`. " \
      "Some resource was temporarily unavailable. It's suggested that you try" \
      "the operation again."
    end

    status_code(26)
  end

  class VirtualProtocolError < CaratError
    def message
      "There was an error relating to virtualization and file access." \
      "It is likely that you need to grant access to or mount some file system correctly."
    end

    status_code(27)
  end

  class OperationNotSupportedError < PermissionError
    def message
      "Attempting to #{action} `#{@path}` is unsupported by your OS."
    end

    status_code(28)
  end

  class NoSpaceOnDeviceError < PermissionError
    def message
      "There was an error while trying to #{action} `#{@path}`. " \
      "There was insufficient space remaining on the device."
    end

    status_code(31)
  end

  class GenericSystemCallError < CaratError
    attr_reader :underlying_error

    def initialize(underlying_error, message)
      @underlying_error = underlying_error
      super("#{message}\nThe underlying system error is #{@underlying_error.class}: #{@underlying_error}")
    end

    status_code(32)
  end
end
