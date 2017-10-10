# frozen_string_literal: true

require "pathname"

module Spec
  module Path
    def root
      @root ||= Pathname.new(File.expand_path("../../..", __FILE__))
    end

    def gemspec
      @gemspec ||= Pathname.new(File.expand_path(root.join("carat.gemspec"), __FILE__))
    end

    def bindir
      @bindir ||= Pathname.new(File.expand_path(root.join("exe"), __FILE__))
    end

    def spec_dir
      @spec_dir ||= Pathname.new(File.expand_path(root.join("spec"), __FILE__))
    end

    def tmp(*path)
      root.join("tmp", *path)
    end

    def home(*path)
      tmp.join("home", *path)
    end

    def default_carat_path(*path)
      if Carat::VERSION.split(".").first.to_i < 2
        system_gem_path(*path)
      else
        carated_app(*[".carat", ENV.fetch("CARATR_SPEC_RUBY_ENGINE", Gem.ruby_engine), Gem::ConfigMap[:ruby_version], *path].compact)
      end
    end

    def carated_app(*path)
      root = tmp.join("carated_app")
      FileUtils.mkdir_p(root)
      root.join(*path)
    end

    alias_method :carated_app1, :carated_app

    def carated_app2(*path)
      root = tmp.join("carated_app2")
      FileUtils.mkdir_p(root)
      root.join(*path)
    end

    def vendored_gems(path = nil)
      carated_app(*["vendor/carat", Gem.ruby_engine, Gem::ConfigMap[:ruby_version], path].compact)
    end

    def cached_gem(path)
      carated_app("vendor/cache/#{path}.gem")
    end

    def base_system_gems
      tmp.join("gems/base")
    end

    def gem_repo1(*args)
      tmp("gems/remote1", *args)
    end

    def gem_repo_missing(*args)
      tmp("gems/missing", *args)
    end

    def gem_repo2(*args)
      tmp("gems/remote2", *args)
    end

    def gem_repo3(*args)
      tmp("gems/remote3", *args)
    end

    def gem_repo4(*args)
      tmp("gems/remote4", *args)
    end

    def security_repo(*args)
      tmp("gems/security_repo", *args)
    end

    def system_gem_path(*path)
      tmp("gems/system", *path)
    end

    def lib_path(*args)
      tmp("libs", *args)
    end

    def carat_path
      Pathname.new(File.expand_path(root.join("lib"), __FILE__))
    end

    def global_plugin_gem(*args)
      home ".carat", "plugin", "gems", *args
    end

    def local_plugin_gem(*args)
      carated_app ".carat", "plugin", "gems", *args
    end

    def tmpdir(*args)
      tmp "tmpdir", *args
    end

    extend self
  end
end
