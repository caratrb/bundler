require "spec_helper"

describe "gemcutter's dependency API" do
  let(:source_hostname) { "localgemserver.test" }
  let(:source_uri) { "http://#{source_hostname}" }

  it "should use the API" do
    gemfile <<-G
      source "#{source_uri}"
      gem "rack"
    G

    carat :install, :artifice => "endpoint"
    expect(out).to include("Fetching gem metadata from #{source_uri}")
    should_be_installed "rack 1.0.0"
  end

  it "should URI encode gem names" do
    gemfile <<-G
      source "#{source_uri}"
      gem " sinatra"
    G

    carat :install, :artifice => "endpoint"
    expect(out).to include("' sinatra' is not a valid gem name because it contains whitespace.")
  end

  it "should handle nested dependencies" do
    gemfile <<-G
      source "#{source_uri}"
      gem "rails"
    G

    carat :install, :artifice => "endpoint"
    expect(out).to include("Fetching gem metadata from #{source_uri}/...")
    should_be_installed(
      "rails 2.3.2",
      "actionpack 2.3.2",
      "activerecord 2.3.2",
      "actionmailer 2.3.2",
      "activeresource 2.3.2",
      "activesupport 2.3.2")
  end

  it "should handle multiple gem dependencies on the same gem" do
    gemfile <<-G
      source "#{source_uri}"
      gem "net-sftp"
    G

    carat :install, :artifice => "endpoint"
    should_be_installed "net-sftp 1.1.1"
  end

  it "should use the endpoint when using --deployment" do
    gemfile <<-G
      source "#{source_uri}"
      gem "rack"
    G
    carat :install, :artifice => "endpoint"

    carat "install --deployment", :artifice => "endpoint"
    expect(out).to include("Fetching gem metadata from #{source_uri}")
    should_be_installed "rack 1.0.0"
  end

  it "handles git dependencies that are in rubygems" do
    build_git "foo" do |s|
      s.executables = "foobar"
      s.add_dependency "rails", "2.3.2"
    end

    gemfile <<-G
      source "#{source_uri}"
      git "file:///#{lib_path('foo-1.0')}" do
        gem 'foo'
      end
    G

    carat :install, :artifice => "endpoint"

    should_be_installed("rails 2.3.2")
  end

  it "handles git dependencies that are in rubygems using --deployment" do
    build_git "foo" do |s|
      s.executables = "foobar"
      s.add_dependency "rails", "2.3.2"
    end

    gemfile <<-G
      source "#{source_uri}"
      gem 'foo', :git => "file:///#{lib_path('foo-1.0')}"
    G

    carat :install, :artifice => "endpoint"

    carat "install --deployment", :artifice => "endpoint"

    should_be_installed("rails 2.3.2")
  end

  it "doesn't fail if you only have a git gem with no deps when using --deployment" do
    build_git "foo"
    gemfile <<-G
      source "#{source_uri}"
      gem 'foo', :git => "file:///#{lib_path('foo-1.0')}"
    G

    carat "install", :artifice => "endpoint"
    carat "install --deployment", :artifice => "endpoint"

    expect(exitstatus).to eq(0) if exitstatus
    should_be_installed("foo 1.0")
  end

  it "falls back when the API errors out" do
    simulate_platform mswin

    gemfile <<-G
      source "#{source_uri}"
      gem "rcov"
    G

    carat :install, :fakeweb => "windows"
    expect(out).to include("Fetching source index from #{source_uri}")
    should_be_installed "rcov 1.0.0"
  end

  it "falls back when hitting the Gemcutter Dependency Limit" do
    gemfile <<-G
      source "#{source_uri}"
      gem "activesupport"
      gem "actionpack"
      gem "actionmailer"
      gem "activeresource"
      gem "thin"
      gem "rack"
      gem "rails"
    G
    carat :install, :artifice => "endpoint_fallback"
    expect(out).to include("Fetching source index from #{source_uri}")

    should_be_installed(
      "activesupport 2.3.2",
      "actionpack 2.3.2",
      "actionmailer 2.3.2",
      "activeresource 2.3.2",
      "activesupport 2.3.2",
      "thin 1.0.0",
      "rack 1.0.0",
      "rails 2.3.2")
  end

  it "falls back when Gemcutter API doesn't return proper Marshal format" do
    gemfile <<-G
      source "#{source_uri}"
      gem "rack"
    G

    carat :install, :verbose => true, :artifice => "endpoint_marshal_fail"
    expect(out).to include("could not fetch from the dependency API, trying the full index")
    should_be_installed "rack 1.0.0"
  end

  it "falls back when the API URL returns 403 Forbidden" do
    gemfile <<-G
      source "#{source_uri}"
      gem "rack"
    G

    carat :install, :verbose => true, :artifice => "endpoint_api_forbidden"
    expect(out).to include("Fetching source index from #{source_uri}")
    should_be_installed "rack 1.0.0"
  end

  it "handles host redirects" do
    gemfile <<-G
      source "#{source_uri}"
      gem "rack"
    G

    carat :install, :artifice => "endpoint_host_redirect"
    should_be_installed "rack 1.0.0"
  end

  it "handles host redirects without Net::HTTP::Persistent" do
    gemfile <<-G
      source "#{source_uri}"
      gem "rack"
    G

    FileUtils.mkdir_p lib_path
    File.open(lib_path("disable_net_http_persistent.rb"), "w") do |h|
      h.write <<-H
        module Kernel
          alias require_without_disabled_net_http require
          def require(*args)
            raise LoadError, 'simulated' if args.first == 'openssl' && !caller.grep(/vendored_persistent/).empty?
            require_without_disabled_net_http(*args)
          end
        end
      H
    end

    carat :install, :artifice => "endpoint_host_redirect", :requires => [lib_path("disable_net_http_persistent.rb")]
    expect(out).to_not match(/Too many redirects/)
    should_be_installed "rack 1.0.0"
  end

  it "timeouts when Carat::Fetcher redirects too much" do
    gemfile <<-G
      source "#{source_uri}"
      gem "rack"
    G

    carat :install, :artifice => "endpoint_redirect"
    expect(out).to match(/Too many redirects/)
  end

  context "when --full-index is specified" do
    it "should use the modern index for install" do
      gemfile <<-G
        source "#{source_uri}"
        gem "rack"
      G

      carat "install --full-index", :artifice => "endpoint"
      expect(out).to include("Fetching source index from #{source_uri}")
      should_be_installed "rack 1.0.0"
    end

    it "should use the modern index for update" do
      gemfile <<-G
        source "#{source_uri}"
        gem "rack"
      G

      carat "update --full-index", :artifice => "endpoint"
      expect(out).to include("Fetching source index from #{source_uri}")
      should_be_installed "rack 1.0.0"
    end
  end

  it "fetches again when more dependencies are found in subsequent sources" do
    build_repo2 do
      build_gem "back_deps" do |s|
        s.add_dependency "foo"
      end
      FileUtils.rm_rf Dir[gem_repo2("gems/foo-*.gem")]
    end

    gemfile <<-G
      source "#{source_uri}"
      source "#{source_uri}/extra"
      gem "back_deps"
    G

    carat :install, :artifice => "endpoint_extra"
    should_be_installed "back_deps 1.0"
  end

  it "fetches gem versions even when those gems are already installed" do
    gemfile <<-G
      source "#{source_uri}"
      gem "rack", "1.0.0"
    G
    carat :install, :artifice => "endpoint_extra_api"

    build_repo4 do
      build_gem "rack", "1.2" do |s|
        s.executables = "rackup"
      end
    end

    gemfile <<-G
      source "#{source_uri}" do; end
      source "#{source_uri}/extra"
      gem "rack", "1.2"
    G
    carat :install, :artifice => "endpoint_extra_api"
    should_be_installed "rack 1.2"
  end

  it "considers all possible versions of dependencies from all api gem sources" do
    # In this scenario, the gem "somegem" only exists in repo4.  It depends on specific version of activesupport that
    # exists only in repo1.  There happens also be a version of activesupport in repo4, but not the one that version 1.0.0
    # of somegem wants. This test makes sure that carat actually finds version 1.2.3 of active support in the other
    # repo and installs it.
    build_repo4 do
      build_gem "activesupport", "1.2.0"
      build_gem "somegem", "1.0.0" do |s|
        s.add_dependency "activesupport", "1.2.3"  #This version exists only in repo1
      end
    end

    gemfile <<-G
      source "#{source_uri}"
      source "#{source_uri}/extra"
      gem 'somegem', '1.0.0'
    G

    carat :install, :artifice => "endpoint_extra_api"

    should_be_installed "somegem 1.0.0"
    should_be_installed "activesupport 1.2.3"
  end

  it "prints API output properly with back deps" do
    build_repo2 do
      build_gem "back_deps" do |s|
        s.add_dependency "foo"
      end
      FileUtils.rm_rf Dir[gem_repo2("gems/foo-*.gem")]
    end

    gemfile <<-G
      source "#{source_uri}"
      source "#{source_uri}/extra"
      gem "back_deps"
    G

    carat :install, :artifice => "endpoint_extra"

    expect(out).to include("Fetching gem metadata from http://localgemserver.test/..")
    expect(out).to include("Fetching source index from http://localgemserver.test/extra")
  end

  it "does not fetch every spec if the index of gems is large when doing back deps" do
    build_repo2 do
      build_gem "back_deps" do |s|
        s.add_dependency "foo"
      end
      build_gem "missing"
      # need to hit the limit
      1.upto(Carat::Source::Rubygems::API_REQUEST_LIMIT) do |i|
        build_gem "gem#{i}"
      end

      FileUtils.rm_rf Dir[gem_repo2("gems/foo-*.gem")]
    end

    gemfile <<-G
      source "#{source_uri}"
      source "#{source_uri}/extra"
      gem "back_deps"
    G

    carat :install, :artifice => "endpoint_extra_missing"
    should_be_installed "back_deps 1.0"
  end

  it "uses the endpoint if all sources support it" do
    gemfile <<-G
      source "#{source_uri}"

      gem 'foo'
    G

    carat :install, :artifice => "endpoint_api_missing"
    should_be_installed "foo 1.0"
  end

  it "fetches again when more dependencies are found in subsequent sources using --deployment" do
    build_repo2 do
      build_gem "back_deps" do |s|
        s.add_dependency "foo"
      end
      FileUtils.rm_rf Dir[gem_repo2("gems/foo-*.gem")]
    end

    gemfile <<-G
      source "#{source_uri}"
      source "#{source_uri}/extra"
      gem "back_deps"
    G

    carat :install, :artifice => "endpoint_extra"

    carat "install --deployment", :artifice => "endpoint_extra"
    should_be_installed "back_deps 1.0"
  end

  it "does not refetch if the only unmet dependency is carat" do
    gemfile <<-G
      source "#{source_uri}"

      gem "carat_dep"
    G

    carat :install, :artifice => "endpoint"
    expect(out).to include("Fetching gem metadata from #{source_uri}")
  end

  it "should install when EndpointSpecification has a bin dir owned by root", :sudo => true do
    sudo "mkdir -p #{system_gem_path("bin")}"
    sudo "chown -R root #{system_gem_path("bin")}"

    gemfile <<-G
      source "#{source_uri}"
      gem "rails"
    G
    carat :install, :artifice => "endpoint"
    should_be_installed "rails 2.3.2"
  end

  it "installs the binstubs" do
    gemfile <<-G
      source "#{source_uri}"
      gem "rack"
    G

    carat "install --binstubs", :artifice => "endpoint"

    gembin "rackup"
    expect(out).to eq("1.0.0")
  end

  it "installs the bins when using --path and uses autoclean" do
    gemfile <<-G
      source "#{source_uri}"
      gem "rack"
    G

    carat "install --path vendor/bundle", :artifice => "endpoint"

    expect(vendored_gems("bin/rackup")).to exist
  end

  it "installs the bins when using --path and uses carat clean" do
    gemfile <<-G
      source "#{source_uri}"
      gem "rack"
    G

    carat "install --path vendor/bundle --no-clean", :artifice => "endpoint"

    expect(vendored_gems("bin/rackup")).to exist
  end

  it "prints post_install_messages" do
    gemfile <<-G
      source "#{source_uri}"
      gem 'rack-obama'
    G

    carat :install, :artifice => "endpoint"
    expect(out).to include("Post-install message from rack:")
  end

  it "should display the post install message for a dependency" do
    gemfile <<-G
      source "#{source_uri}"
      gem 'rack_middleware'
    G

    carat :install, :artifice => "endpoint"
    expect(out).to include("Post-install message from rack:")
    expect(out).to include("Rack's post install message")
  end

  context "when using basic authentication" do
    let(:user)     { "user" }
    let(:password) { "pass" }
    let(:basic_auth_source_uri) do
      uri          = URI.parse(source_uri)
      uri.user     = user
      uri.password = password

      uri
    end

    it "passes basic authentication details and strips out creds" do
      gemfile <<-G
        source "#{basic_auth_source_uri}"
        gem "rack"
      G

      carat :install, :artifice => "endpoint_basic_authentication"
      expect(out).not_to include("#{user}:#{password}")
      should_be_installed "rack 1.0.0"
    end

    it "strips http basic authentication creds for modern index" do
      gemfile <<-G
        source "#{basic_auth_source_uri}"
        gem "rack"
      G

      carat :install, :artifice => "endopint_marshal_fail_basic_authentication"
      expect(out).not_to include("#{user}:#{password}")
      should_be_installed "rack 1.0.0"
    end

    it "strips http basic auth creds when it can't reach the server" do
      gemfile <<-G
        source "#{basic_auth_source_uri}"
        gem "rack"
      G

      carat :install, :artifice => "endpoint_500"
      expect(out).not_to include("#{user}:#{password}")
    end

    it "strips http basic auth creds when warning about ambiguous sources" do
      gemfile <<-G
        source "#{basic_auth_source_uri}"
        source "file://#{gem_repo1}"
        gem "rack"
      G

      carat :install, :artifice => "endpoint_basic_authentication"
      expect(out).to include("Warning: the gem 'rack' was found in multiple sources.")
      expect(out).not_to include("#{user}:#{password}")
      should_be_installed "rack 1.0.0"
    end

    it "does not pass the user / password to different hosts on redirect" do
      gemfile <<-G
        source "#{basic_auth_source_uri}"
        gem "rack"
      G

      carat :install, :artifice => "endpoint_creds_diff_host"
      should_be_installed "rack 1.0.0"
    end

    describe "with authentication details in carat config" do
      before do
        gemfile <<-G
          source "#{source_uri}"
          gem "rack"
        G
      end

      it "reads authentication details by host name from carat config" do
        carat "config #{source_hostname} #{user}:#{password}"

        carat :install, :artifice => "endpoint_strict_basic_authentication"

        expect(out).to include("Fetching gem metadata from #{source_uri}")
        should_be_installed "rack 1.0.0"
      end

      it "reads authentication details by full url from carat config" do
        # The trailing slash is necessary here; Fetcher canonicalizes the URI.
        carat "config #{source_uri}/ #{user}:#{password}"

        carat :install, :artifice => "endpoint_strict_basic_authentication"

        expect(out).to include("Fetching gem metadata from #{source_uri}")
        should_be_installed "rack 1.0.0"
      end

      it "should use the API" do
        carat "config #{source_hostname} #{user}:#{password}"
        carat :install, :artifice => "endpoint_strict_basic_authentication"
        expect(out).to include("Fetching gem metadata from #{source_uri}")
        should_be_installed "rack 1.0.0"
      end

      it "prefers auth supplied in the source uri" do
        gemfile <<-G
          source "#{basic_auth_source_uri}"
          gem "rack"
        G

        carat "config #{source_hostname} otheruser:wrong"

        carat :install, :artifice => "endpoint_strict_basic_authentication"
        should_be_installed "rack 1.0.0"
      end

      it "shows instructions if auth is not provided for the source" do
        carat :install, :artifice => "endpoint_strict_basic_authentication"
        expect(out).to include("carat config #{source_hostname} username:password")
      end

      it "fails if authentication has already been provided, but failed" do
        carat "config #{source_hostname} #{user}:wrong"

        carat :install, :artifice => "endpoint_strict_basic_authentication"
        expect(out).to include("Bad username or password")
      end
    end

    describe "with no password" do
      let(:password) { nil }

      it "passes basic authentication details" do
        gemfile <<-G
          source "#{basic_auth_source_uri}"
          gem "rack"
        G

        carat :install, :artifice => "endpoint_basic_authentication"
        should_be_installed "rack 1.0.0"
      end
    end
  end

  context "when ruby is compiled without openssl" do
    before do
      # Install a monkeypatch that reproduces the effects of openssl being
      # missing when the fetcher runs, as happens in real life. The reason
      # we can't just overwrite openssl.rb is that Artifice uses it.
      bundled_app("broken_ssl").mkpath
      bundled_app("broken_ssl/openssl.rb").open("w") do |f|
        f.write <<-RUBY
          raise LoadError, "cannot load such file -- openssl"
        RUBY
      end
    end

    it "explains what to do to get it" do
      gemfile <<-G
        source "#{source_uri.gsub(/http/, 'https')}"
        gem "rack"
      G

      carat :install, :env => {"RUBYOPT" => "-I#{bundled_app("broken_ssl")}"}
      expect(out).to include("OpenSSL")
    end
  end

  context "when SSL certificate verification fails" do
    it "explains what happened" do
      # Install a monkeypatch that reproduces the effects of openssl raising
      # a certificate validation error when Rubygems tries to connect.
      gemfile <<-G
        class Net::HTTP
          def start
            raise OpenSSL::SSL::SSLError, "certificate verify failed"
          end
        end

        source "#{source_uri.gsub(/http/, 'https')}"
        gem "rack"
      G

      carat :install
      expect(out).to match(/could not verify the SSL certificate/i)
    end
  end

  context ".gemrc with sources is present" do
    before do
      File.open(home('.gemrc'), 'w') do |file|
        file.puts({:sources => ["https://rubygems.org"]}.to_yaml)
      end
    end

    after do
      home('.gemrc').rmtree
    end

    it "uses other sources declared in the Gemfile" do
      gemfile <<-G
        source "#{source_uri}"
        gem 'rack'
      G

      carat "install", :artifice => "endpoint_marshal_fail"

      expect(exitstatus).to eq(0) if exitstatus
    end
  end

end
