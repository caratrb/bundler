# frozen_string_literal: true

require "uri"
require "rubygems/user_interaction"

module Carat
  class Source
    class Rubygems < Source
      autoload :Remote, "carat/source/rubygems/remote"

      # Use the API when installing less than X gems
      API_REQUEST_LIMIT = 500
      # Ask for X gems per API request
      API_REQUEST_SIZE = 50

      attr_reader :remotes, :caches

      def initialize(options = {})
        @options = options
        @remotes = []
        @dependency_names = []
        @allow_remote = false
        @allow_cached = false
        @caches = [cache_path, *Carat.rubygems.gem_cache]

        Array(options["remotes"] || []).reverse_each {|r| add_remote(r) }
      end

      def remote!
        @specs = nil
        @allow_remote = true
      end

      def cached!
        @specs = nil
        @allow_cached = true
      end

      def hash
        @remotes.hash
      end

      def eql?(other)
        other.is_a?(Rubygems) && other.credless_remotes == credless_remotes
      end

      alias_method :==, :eql?

      def include?(o)
        o.is_a?(Rubygems) && (o.credless_remotes - credless_remotes).empty?
      end

      def can_lock?(spec)
        return super if Carat.feature_flag.lockfile_uses_separate_rubygems_sources?
        spec.source.is_a?(Rubygems)
      end

      def options
        { "remotes" => @remotes.map(&:to_s) }
      end

      def self.from_lock(options)
        new(options)
      end

      def to_lock
        out = String.new("GEM\n")
        remotes.reverse_each do |remote|
          out << "  remote: #{suppress_configured_credentials remote}\n"
        end
        out << "  specs:\n"
      end

      def to_s
        if remotes.empty?
          "locally installed gems"
        else
          remote_names = remotes.map(&:to_s).join(", ")
          "rubygems repository #{remote_names} or installed locally"
        end
      end
      alias_method :name, :to_s

      def specs
        @specs ||= begin
          # remote_specs usually generates a way larger Index than the other
          # sources, and large_idx.use small_idx is way faster than
          # small_idx.use large_idx.
          idx = @allow_remote ? remote_specs.dup : Index.new
          idx.use(cached_specs, :override_dupes) if @allow_cached || @allow_remote
          idx.use(installed_specs, :override_dupes)
          idx
        end
      end

      def install(spec, opts = {})
        force = opts[:force]
        ensure_builtin_gems_cached = opts[:ensure_builtin_gems_cached]

        if ensure_builtin_gems_cached && builtin_gem?(spec)
          if !cached_path(spec)
            cached_built_in_gem(spec) unless spec.remote
            force = true
          else
            spec.loaded_from = loaded_from(spec)
          end
        end

        if installed?(spec) && !force
          print_using_message "Using #{version_message(spec)}"
          return nil # no post-install message
        end

        # Download the gem to get the spec, because some specs that are returned
        # by rubygems.org are broken and wrong.
        if spec.remote
          # Check for this spec from other sources
          uris = [spec.remote.anonymized_uri]
          uris += remotes_for_spec(spec).map(&:anonymized_uri)
          uris.uniq!
          Installer.ambiguous_gems << [spec.name, *uris] if uris.length > 1

          path = fetch_gem(spec)
          begin
            s = Carat.rubygems.spec_from_gem(path, Carat.settings["trust-policy"])
            spec.__swap__(s)
          rescue
            Carat.rm_rf(path)
            raise
          end
        end

        unless Carat.settings[:no_install]
          message = "Installing #{version_message(spec)}"
          message += " with native extensions" if spec.extensions.any?
          Carat.ui.confirm message

          path = cached_gem(spec)
          if requires_sudo?
            install_path = Carat.tmp(spec.full_name)
            bin_path     = install_path.join("bin")
          else
            install_path = rubygems_dir
            bin_path     = Carat.system_bindir
          end

          installed_spec = nil
          Carat.rubygems.preserve_paths do
            installed_spec = Carat::RubyGemsGemInstaller.at(
              path,
              :install_dir         => install_path.to_s,
              :bin_dir             => bin_path.to_s,
              :ignore_dependencies => true,
              :wrappers            => true,
              :env_shebang         => true,
              :build_args          => opts[:build_args],
              :carat_expected_checksum => spec.respond_to?(:checksum) && spec.checksum,
              :carat_extension_cache_path => extension_cache_path(spec)
            ).install
          end
          spec.full_gem_path = installed_spec.full_gem_path

          # SUDO HAX
          if requires_sudo?
            Carat.rubygems.repository_subdirectories.each do |name|
              src = File.join(install_path, name, "*")
              dst = File.join(rubygems_dir, name)
              if name == "extensions" && Dir.glob(src).any?
                src = File.join(src, "*/*")
                ext_src = Dir.glob(src).first
                ext_src.gsub!(src[0..-6], "")
                dst = File.dirname(File.join(dst, ext_src))
              end
              SharedHelpers.filesystem_access(dst) do |p|
                Carat.mkdir_p(p)
              end
              Carat.sudo "cp -R #{src} #{dst}" if Dir[src].any?
            end

            spec.executables.each do |exe|
              SharedHelpers.filesystem_access(Carat.system_bindir) do |p|
                Carat.mkdir_p(p)
              end
              Carat.sudo "cp -R #{install_path}/bin/#{exe} #{Carat.system_bindir}/"
            end
          end
          installed_spec.loaded_from = loaded_from(spec)
        end
        spec.loaded_from = loaded_from(spec)

        spec.post_install_message
      ensure
        Carat.rm_rf(install_path) if requires_sudo?
      end

      def cache(spec, custom_path = nil)
        if builtin_gem?(spec)
          cached_path = cached_built_in_gem(spec)
        else
          cached_path = cached_gem(spec)
        end
        raise GemNotFound, "Missing gem file '#{spec.full_name}.gem'." unless cached_path
        return if File.dirname(cached_path) == Carat.app_cache.to_s
        Carat.ui.info "  * #{File.basename(cached_path)}"
        FileUtils.cp(cached_path, Carat.app_cache(custom_path))
      rescue Errno::EACCES => e
        Carat.ui.debug(e)
        raise InstallError, e.message
      end

      def cached_built_in_gem(spec)
        cached_path = cached_path(spec)
        if cached_path.nil?
          remote_spec = remote_specs.search(spec).first
          if remote_spec
            cached_path = fetch_gem(remote_spec)
          else
            Carat.ui.warn "#{spec.full_name} is built in to Ruby, and can't be cached because your Gemfile doesn't have any sources that contain it."
          end
        end
        cached_path
      end

      def add_remote(source)
        uri = normalize_uri(source)
        @remotes.unshift(uri) unless @remotes.include?(uri)
      end

      def equivalent_remotes?(other_remotes)
        other_remotes.map(&method(:remove_auth)) == @remotes.map(&method(:remove_auth))
      end

      def replace_remotes(other_remotes, allow_equivalent = false)
        return false if other_remotes == @remotes

        equivalent = allow_equivalent && equivalent_remotes?(other_remotes)

        @remotes = []
        other_remotes.reverse_each do |r|
          add_remote r.to_s
        end

        !equivalent
      end

      def unmet_deps
        if @allow_remote && api_fetchers.any?
          remote_specs.unmet_dependency_names
        else
          []
        end
      end

      def fetchers
        @fetchers ||= remotes.map do |uri|
          remote = Source::Rubygems::Remote.new(uri)
          Carat::Fetcher.new(remote)
        end
      end

      def double_check_for(unmet_dependency_names, override_dupes = false, index = specs)
        return unless @allow_remote
        raise ArgumentError, "missing index" unless index

        return unless api_fetchers.any?

        unmet_dependency_names = unmet_dependency_names.call
        unless unmet_dependency_names.nil?
          if api_fetchers.size <= 1
            # can't do this when there are multiple fetchers because then we might not fetch from _all_
            # of them
            unmet_dependency_names -= remote_specs.spec_names # avoid re-fetching things we've already gotten
          end
          return if unmet_dependency_names.empty?
        end

        Carat.ui.debug "Double checking for #{unmet_dependency_names || "all specs (due to the size of the request)"} in #{self}"

        fetch_names(api_fetchers, unmet_dependency_names, index, override_dupes)
      end

      def dependency_names_to_double_check
        names = []
        remote_specs.each do |spec|
          case spec
          when EndpointSpecification, Gem::Specification, StubSpecification, LazySpecification
            names.concat(spec.runtime_dependencies)
          when RemoteSpecification # from the full index
            return nil
          else
            raise "unhandled spec type (#{spec.inspect})"
          end
        end
        names.map!(&:name) if names
        names
      end

    protected

      def credless_remotes
        remotes.map(&method(:suppress_configured_credentials))
      end

      def remotes_for_spec(spec)
        specs.search_all(spec.name).inject([]) do |uris, s|
          uris << s.remote if s.remote
          uris
        end
      end

      def loaded_from(spec)
        "#{rubygems_dir}/specifications/#{spec.full_name}.gemspec"
      end

      def cached_gem(spec)
        cached_gem = cached_path(spec)
        unless cached_gem
          raise Carat::GemNotFound, "Could not find #{spec.file_name} for installation"
        end
        cached_gem
      end

      def cached_path(spec)
        possibilities = @caches.map {|p| "#{p}/#{spec.file_name}" }
        possibilities.find {|p| File.exist?(p) }
      end

      def normalize_uri(uri)
        uri = uri.to_s
        uri = "#{uri}/" unless uri =~ %r{/$}
        uri = URI(uri)
        raise ArgumentError, "The source must be an absolute URI. For example:\n" \
          "source 'https://rubygems.org'" if !uri.absolute? || (uri.is_a?(URI::HTTP) && uri.host.nil?)
        uri
      end

      def suppress_configured_credentials(remote)
        remote_nouser = remove_auth(remote)
        if remote.userinfo && remote.userinfo == Carat.settings[remote_nouser]
          remote_nouser
        else
          remote
        end
      end

      def remove_auth(remote)
        remote.dup.tap {|uri| uri.user = uri.password = nil }.to_s
      end

      def installed_specs
        @installed_specs ||= Index.build do |idx|
          Carat.rubygems.all_specs.reverse_each do |spec|
            next if spec.name == "carat"
            spec.source = self
            if Carat.rubygems.spec_missing_extensions?(spec, false)
              Carat.ui.debug "Source #{self} is ignoring #{spec} because it is missing extensions"
              next
            end
            idx << spec
          end
        end
      end

      def cached_specs
        @cached_specs ||= begin
          idx = installed_specs.dup

          Dir["#{cache_path}/*.gem"].each do |gemfile|
            next if gemfile =~ /^carat\-[\d\.]+?\.gem/
            s ||= Carat.rubygems.spec_from_gem(gemfile)
            s.source = self
            if Carat.rubygems.spec_missing_extensions?(s, false)
              Carat.ui.debug "Source #{self} is ignoring #{s} because it is missing extensions"
              next
            end
            idx << s
          end

          idx
        end
      end

      def api_fetchers
        fetchers.select {|f| f.use_api && f.fetchers.first.api_fetcher? }
      end

      def remote_specs
        @remote_specs ||= Index.build do |idx|
          index_fetchers = fetchers - api_fetchers

          # gather lists from non-api sites
          fetch_names(index_fetchers, nil, idx, false)

          # because ensuring we have all the gems we need involves downloading
          # the gemspecs of those gems, if the non-api sites contain more than
          # about 500 gems, we treat all sites as non-api for speed.
          allow_api = idx.size < API_REQUEST_LIMIT && dependency_names.size < API_REQUEST_LIMIT
          Carat.ui.debug "Need to query more than #{API_REQUEST_LIMIT} gems." \
            " Downloading full index instead..." unless allow_api

          fetch_names(api_fetchers, allow_api && dependency_names, idx, false)
        end
      end

      def fetch_names(fetchers, dependency_names, index, override_dupes)
        fetchers.each do |f|
          if dependency_names
            Carat.ui.info "Fetching gem metadata from #{f.uri}", Carat.ui.debug?
            index.use f.specs_with_retry(dependency_names, self), override_dupes
            Carat.ui.info "" unless Carat.ui.debug? # new line now that the dots are over
          else
            Carat.ui.info "Fetching source index from #{f.uri}"
            index.use f.specs_with_retry(nil, self), override_dupes
          end
        end
      end

      def fetch_gem(spec)
        return false unless spec.remote

        spec.fetch_platform

        download_path = requires_sudo? ? Carat.tmp(spec.full_name) : rubygems_dir
        gem_path = "#{rubygems_dir}/cache/#{spec.full_name}.gem"

        SharedHelpers.filesystem_access("#{download_path}/cache") do |p|
          FileUtils.mkdir_p(p)
        end
        download_gem(spec, download_path)

        if requires_sudo?
          SharedHelpers.filesystem_access("#{rubygems_dir}/cache") do |p|
            Carat.mkdir_p(p)
          end
          Carat.sudo "mv #{download_path}/cache/#{spec.full_name}.gem #{gem_path}"
        end

        gem_path
      ensure
        Carat.rm_rf(download_path) if requires_sudo?
      end

      def builtin_gem?(spec)
        # Ruby 2.1, where all included gems have this summary
        return true if spec.summary =~ /is carated with Ruby/

        # Ruby 2.0, where gemspecs are stored in specifications/default/
        spec.loaded_from && spec.loaded_from.include?("specifications/default/")
      end

      def installed?(spec)
        installed_specs[spec].any?
      end

      def requires_sudo?
        Carat.requires_sudo?
      end

      def rubygems_dir
        Carat.rubygems.gem_dir
      end

      def cache_path
        Carat.app_cache
      end

    private

      # Checks if the requested spec exists in the global cache. If it does,
      # we copy it to the download path, and if it does not, we download it.
      #
      # @param  [Specification] spec
      #         the spec we want to download or retrieve from the cache.
      #
      # @param  [String] download_path
      #         the local directory the .gem will end up in.
      #
      def download_gem(spec, download_path)
        local_path = File.join(download_path, "cache/#{spec.full_name}.gem")

        if (cache_path = download_cache_path(spec)) && cache_path.file?
          SharedHelpers.filesystem_access(local_path) do
            FileUtils.cp(cache_path, local_path)
          end
        else
          uri = spec.remote.uri
          Carat.ui.confirm("Fetching #{version_message(spec)}")
          Carat.rubygems.download_gem(spec, uri, download_path)
          cache_globally(spec, local_path)
        end
      end

      # Checks if the requested spec exists in the global cache. If it does
      # not, we create the relevant global cache subdirectory if it does not
      # exist and copy the spec from the local cache to the global cache.
      #
      # @param  [Specification] spec
      #         the spec we want to copy to the global cache.
      #
      # @param  [String] local_cache_path
      #         the local directory from which we want to copy the .gem.
      #
      def cache_globally(spec, local_cache_path)
        return unless cache_path = download_cache_path(spec)
        return if cache_path.exist?

        SharedHelpers.filesystem_access(cache_path.dirname, &:mkpath)
        SharedHelpers.filesystem_access(cache_path) do
          FileUtils.cp(local_cache_path, cache_path)
        end
      end

      # Returns the global cache path of the calling Rubygems::Source object.
      #
      # Note that the Source determines the path's subdirectory. We use this
      # subdirectory in the global cache path so that gems with the same name
      # -- and possibly different versions -- from different sources are saved
      # to their respective subdirectories and do not override one another.
      #
      # @param  [Gem::Specification] specification
      #
      # @return [Pathname] The global cache path.
      #
      def download_cache_path(spec)
        return unless Carat.feature_flag.global_gem_cache?
        return unless remote = spec.remote
        return unless cache_slug = remote.cache_slug

        Carat.user_cache.join("gems", cache_slug, spec.file_name)
      end

      def extension_cache_slug(spec)
        return unless remote = spec.remote
        remote.cache_slug
      end
    end
  end
end
