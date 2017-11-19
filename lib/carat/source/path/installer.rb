module Carat
  class Source
    class Path

      class Installer < Carat::GemInstaller
        attr_reader :spec

        def initialize(spec, options = {})
          @spec              = spec
          @gem_dir           = Carat.rubygems.path(spec.full_gem_path)
          @wrappers          = options[:wrappers] || true
          @env_shebang       = options[:env_shebang] || true
          @format_executable = options[:format_executable] || false
          @build_args        = options[:build_args] || Carat.rubygems.build_args
          @gem_bin_dir       = "#{Carat.rubygems.gem_dir}/bin"

          if Carat.requires_sudo?
            @tmp_dir = Carat.tmp(spec.full_name).to_s
            @bin_dir = "#{@tmp_dir}/bin"
          else
            @bin_dir = @gem_bin_dir
          end
        end

        def generate_bin
          return if spec.executables.nil? || spec.executables.empty?

          super

          if Carat.requires_sudo?
            Carat.mkdir_p @gem_bin_dir
            spec.executables.each do |exe|
              Carat.sudo "cp -R #{@bin_dir}/#{exe} #{@gem_bin_dir}"
            end
          end
        ensure
          Carat.rm_rf(@tmp_dir) if Carat.requires_sudo?
        end
      end

    end
  end
end
