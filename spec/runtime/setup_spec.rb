# frozen_string_literal: true

RSpec.describe "Carat.setup" do
  describe "with no arguments" do
    it "makes all groups available" do
      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack", :group => :test
      G

      ruby <<-RUBY
        require 'rubygems'
        require 'carat'
        Carat.setup

        require 'rack'
        puts RACK
      RUBY
      expect(err).to lack_errors
      expect(out).to eq("1.0.0")
    end
  end

  describe "when called with groups" do
    before(:each) do
      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "yard"
        gem "rack", :group => :test
      G
    end

    it "doesn't make all groups available" do
      ruby <<-RUBY
        require 'rubygems'
        require 'carat'
        Carat.setup(:default)

        begin
          require 'rack'
        rescue LoadError
          puts "WIN"
        end
      RUBY
      expect(err).to lack_errors
      expect(out).to eq("WIN")
    end

    it "accepts string for group name" do
      ruby <<-RUBY
        require 'rubygems'
        require 'carat'
        Carat.setup(:default, 'test')

        require 'rack'
        puts RACK
      RUBY
      expect(err).to lack_errors
      expect(out).to eq("1.0.0")
    end

    it "leaves all groups available if they were already" do
      ruby <<-RUBY
        require 'rubygems'
        require 'carat'
        Carat.setup
        Carat.setup(:default)

        require 'rack'
        puts RACK
      RUBY
      expect(err).to lack_errors
      expect(out).to eq("1.0.0")
    end

    it "leaves :default available if setup is called twice" do
      ruby <<-RUBY
        require 'rubygems'
        require 'carat'
        Carat.setup(:default)
        Carat.setup(:default, :test)

        begin
          require 'yard'
          puts "WIN"
        rescue LoadError
          puts "FAIL"
        end
      RUBY
      expect(err).to lack_errors
      expect(out).to match("WIN")
    end

    it "handles multiple non-additive invocations" do
      ruby <<-RUBY
        require 'carat'
        Carat.setup(:default, :test)
        Carat.setup(:default)
        require 'rack'

        puts "FAIL"
      RUBY

      expect(err).to match("rack")
      expect(err).to match("LoadError")
      expect(out).not_to match("FAIL")
    end
  end

  context "load order" do
    def clean_load_path(lp)
      without_carat_load_path = ruby!("puts $LOAD_PATH").split("\n")
      lp = lp - [
        carat_path.to_s,
        carat_path.join("gems/carat-#{Carat::VERSION}/lib").to_s,
        tmp("rubygems/lib").to_s,
        root.join("../lib").expand_path.to_s,
      ] - without_carat_load_path
      lp.map! {|p| p.sub(/^#{Regexp.union system_gem_path.to_s, default_carat_path.to_s}/i, "") }
    end

    it "puts loaded gems after -I and RUBYLIB" do
      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"
      G

      ENV["RUBYOPT"] = "-Idash_i_dir"
      ENV["RUBYLIB"] = "rubylib_dir"

      ruby <<-RUBY
        require 'rubygems'
        require 'carat'
        Carat.setup
        puts $LOAD_PATH
      RUBY

      load_path = out.split("\n")
      rack_load_order = load_path.index {|path| path.include?("rack") }

      expect(err).to eq("")
      expect(load_path[1]).to include "dash_i_dir"
      expect(load_path[2]).to include "rubylib_dir"
      expect(rack_load_order).to be > 0
    end

    it "orders the load path correctly when there are dependencies" do
      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rails"
      G

      ruby! <<-RUBY
        require 'rubygems'
        require 'carat'
        Carat.setup
        puts $LOAD_PATH
      RUBY

      load_path = clean_load_path(out.split("\n"))

      expect(load_path).to start_with(
        "/gems/rails-2.3.2/lib",
        "/gems/activeresource-2.3.2/lib",
        "/gems/activerecord-2.3.2/lib",
        "/gems/actionpack-2.3.2/lib",
        "/gems/actionmailer-2.3.2/lib",
        "/gems/activesupport-2.3.2/lib",
        "/gems/rake-10.0.2/lib"
      )
    end

    it "falls back to order the load path alphabetically for backwards compatibility" do
      install_gemfile! <<-G
        source "file://#{gem_repo1}"
        gem "weakling"
        gem "duradura"
        gem "terranova"
      G

      ruby! <<-RUBY
        require 'rubygems'
        require 'carat/setup'
        puts $LOAD_PATH
      RUBY

      load_path = clean_load_path(out.split("\n"))

      expect(load_path).to start_with(
        "/gems/weakling-0.0.3/lib",
        "/gems/terranova-8/lib",
        "/gems/duradura-7.0/lib"
      )
    end
  end

  it "raises if the Gemfile was not yet installed" do
    gemfile <<-G
      source "file://#{gem_repo1}"
      gem "rack"
    G

    ruby <<-R
      require 'rubygems'
      require 'carat'

      begin
        Carat.setup
        puts "FAIL"
      rescue Carat::GemNotFound
        puts "WIN"
      end
    R

    expect(out).to eq("WIN")
  end

  it "doesn't create a Gemfile.lock if the setup fails" do
    gemfile <<-G
      source "file://#{gem_repo1}"
      gem "rack"
    G

    ruby <<-R
      require 'rubygems'
      require 'carat'

      Carat.setup
    R

    expect(carated_app("Gemfile.lock")).not_to exist
  end

  it "doesn't change the Gemfile.lock if the setup fails" do
    install_gemfile <<-G
      source "file://#{gem_repo1}"
      gem "rack"
    G

    lockfile = File.read(carated_app("Gemfile.lock"))

    gemfile <<-G
      source "file://#{gem_repo1}"
      gem "rack"
      gem "nosuchgem", "10.0"
    G

    ruby <<-R
      require 'rubygems'
      require 'carat'

      Carat.setup
    R

    expect(File.read(carated_app("Gemfile.lock"))).to eq(lockfile)
  end

  it "makes a Gemfile.lock if setup succeeds" do
    install_gemfile <<-G
      source "file://#{gem_repo1}"
      gem "rack"
    G

    File.read(carated_app("Gemfile.lock"))

    FileUtils.rm(carated_app("Gemfile.lock"))

    run "1"
    expect(carated_app("Gemfile.lock")).to exist
  end

  describe "$CARAT_GEMFILE" do
    context "user provides an absolute path" do
      it "uses CARAT_GEMFILE to locate the gemfile if present" do
        gemfile <<-G
          source "file://#{gem_repo1}"
          gem "rack"
        G

        gemfile carated_app("4realz"), <<-G
          source "file://#{gem_repo1}"
          gem "activesupport", "2.3.5"
        G

        ENV["CARAT_GEMFILE"] = carated_app("4realz").to_s
        carat :install

        expect(the_carat).to include_gems "activesupport 2.3.5"
      end
    end

    context "an absolute path is not provided" do
      it "uses CARAT_GEMFILE to locate the gemfile if present" do
        gemfile <<-G
          source "file://#{gem_repo1}"
        G

        carat "install"
        carat "install --deployment"

        ENV["CARAT_GEMFILE"] = "Gemfile"
        ruby <<-R
          require 'rubygems'
          require 'carat'

          begin
            Carat.setup
            puts "WIN"
          rescue ArgumentError => e
            puts "FAIL"
          end
        R

        expect(out).to eq("WIN")
      end
    end
  end

  it "prioritizes gems in CARAT_PATH over gems in GEM_HOME" do
    ENV["CARAT_PATH"] = carated_app(".carat").to_s
    install_gemfile <<-G
      source "file://#{gem_repo1}"
      gem "rack", "1.0.0"
    G

    build_gem "rack", "1.0", :to_system => true do |s|
      s.write "lib/rack.rb", "RACK = 'FAIL'"
    end

    expect(the_carat).to include_gems "rack 1.0.0"
  end

  describe "integrate with rubygems" do
    describe "by replacing #gem" do
      before :each do
        install_gemfile <<-G
          source "file://#{gem_repo1}"
          gem "rack", "0.9.1"
        G
      end

      it "replaces #gem but raises when the gem is missing" do
        run <<-R
          begin
            gem "activesupport"
            puts "FAIL"
          rescue LoadError
            puts "WIN"
          end
        R

        expect(out).to eq("WIN")
      end

      it "version_requirement is now deprecated in rubygems 1.4.0+ when gem is missing" do
        run <<-R
          begin
            gem "activesupport"
            puts "FAIL"
          rescue LoadError
            puts "WIN"
          end
        R

        expect(err).to lack_errors
      end

      it "replaces #gem but raises when the version is wrong" do
        run <<-R
          begin
            gem "rack", "1.0.0"
            puts "FAIL"
          rescue LoadError
            puts "WIN"
          end
        R

        expect(out).to eq("WIN")
      end

      it "version_requirement is now deprecated in rubygems 1.4.0+ when the version is wrong" do
        run <<-R
          begin
            gem "rack", "1.0.0"
            puts "FAIL"
          rescue LoadError
            puts "WIN"
          end
        R

        expect(err).to lack_errors
      end
    end

    describe "by hiding system gems" do
      before :each do
        system_gems "activesupport-2.3.5"
        install_gemfile <<-G
          source "file://#{gem_repo1}"
          gem "yard"
        G
      end

      it "removes system gems from Gem.source_index" do
        run "require 'yard'"
        expect(out).to eq("carat-#{Carat::VERSION}\nyard-1.0")
      end

      context "when the ruby stdlib is a substring of Gem.path" do
        it "does not reject the stdlib from $LOAD_PATH" do
          substring = "/" + $LOAD_PATH.find {|p| p =~ /vendor_ruby/ }.split("/")[2]
          run "puts 'worked!'", :env => { "GEM_PATH" => substring }
          expect(out).to eq("worked!")
        end
      end
    end
  end

  describe "with paths" do
    it "activates the gems in the path source" do
      system_gems "rack-1.0.0"

      build_lib "rack", "1.0.0" do |s|
        s.write "lib/rack.rb", "puts 'WIN'"
      end

      gemfile <<-G
        source "file://#{gem_repo1}"
        path "#{lib_path("rack-1.0.0")}" do
          gem "rack"
        end
      G

      run "require 'rack'"
      expect(out).to eq("WIN")
    end
  end

  describe "with git" do
    before do
      build_git "rack", "1.0.0"

      gemfile <<-G
        gem "rack", :git => "#{lib_path("rack-1.0.0")}"
      G
    end

    it "provides a useful exception when the git repo is not checked out yet" do
      run "1"
      expect(err).to match(/the git source #{lib_path('rack-1.0.0')} is not yet checked out. Please run `carat install`/i)
    end

    it "does not hit the git binary if the lockfile is available and up to date" do
      carat "install"

      break_git!

      ruby <<-R
        require 'rubygems'
        require 'carat'

        begin
          Carat.setup
          puts "WIN"
        rescue Exception => e
          puts "FAIL"
        end
      R

      expect(out).to eq("WIN")
    end

    it "provides a good exception if the lockfile is unavailable" do
      carat "install"

      FileUtils.rm(carated_app("Gemfile.lock"))

      break_git!

      ruby <<-R
        require "rubygems"
        require "carat"

        begin
          Carat.setup
          puts "FAIL"
        rescue Carat::GitError => e
          puts e.message
        end
      R

      run "puts 'FAIL'"

      expect(err).not_to include "This is not the git you are looking for"
    end

    it "works even when the cache directory has been deleted" do
      carat! :install, forgotten_command_line_options(:path => "vendor/carat")
      FileUtils.rm_rf vendored_gems("cache")
      expect(the_carat).to include_gems "rack 1.0.0"
    end

    it "does not randomly change the path when specifying --path and the carat directory becomes read only" do
      carat! :install, forgotten_command_line_options(:path => "vendor/carat")

      with_read_only("**/*") do
        expect(the_carat).to include_gems "rack 1.0.0"
      end
    end

    it "finds git gem when default carat path becomes read only" do
      carat "install"

      with_read_only("#{Carat.carat_path}/**/*") do
        expect(the_carat).to include_gems "rack 1.0.0"
      end
    end
  end

  describe "when specifying local override" do
    it "explodes if given path does not exist on runtime" do
      build_git "rack", "0.8"

      FileUtils.cp_r("#{lib_path("rack-0.8")}/.", lib_path("local-rack"))

      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack", :git => "#{lib_path("rack-0.8")}", :branch => "master"
      G

      carat %(config local.rack #{lib_path("local-rack")})
      carat! :install

      FileUtils.rm_rf(lib_path("local-rack"))
      run "require 'rack'"
      expect(err).to match(/Cannot use local override for rack-0.8 because #{Regexp.escape(lib_path('local-rack').to_s)} does not exist/)
    end

    it "explodes if branch is not given on runtime" do
      build_git "rack", "0.8"

      FileUtils.cp_r("#{lib_path("rack-0.8")}/.", lib_path("local-rack"))

      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack", :git => "#{lib_path("rack-0.8")}", :branch => "master"
      G

      carat %(config local.rack #{lib_path("local-rack")})
      carat! :install

      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack", :git => "#{lib_path("rack-0.8")}"
      G

      run "require 'rack'"
      expect(err).to match(/because :branch is not specified in Gemfile/)
    end

    it "explodes on different branches on runtime" do
      build_git "rack", "0.8"

      FileUtils.cp_r("#{lib_path("rack-0.8")}/.", lib_path("local-rack"))

      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack", :git => "#{lib_path("rack-0.8")}", :branch => "master"
      G

      carat %(config local.rack #{lib_path("local-rack")})
      carat! :install

      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack", :git => "#{lib_path("rack-0.8")}", :branch => "changed"
      G

      run "require 'rack'"
      expect(err).to match(/is using branch master but Gemfile specifies changed/)
    end

    it "explodes on refs with different branches on runtime" do
      build_git "rack", "0.8"

      FileUtils.cp_r("#{lib_path("rack-0.8")}/.", lib_path("local-rack"))

      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack", :git => "#{lib_path("rack-0.8")}", :ref => "master", :branch => "master"
      G

      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack", :git => "#{lib_path("rack-0.8")}", :ref => "master", :branch => "nonexistant"
      G

      carat %(config local.rack #{lib_path("local-rack")})
      run "require 'rack'"
      expect(err).to match(/is using branch master but Gemfile specifies nonexistant/)
    end
  end

  describe "when excluding groups" do
    it "doesn't change the resolve if --without is used" do
      install_gemfile <<-G, forgotten_command_line_options(:without => :rails)
        source "file://#{gem_repo1}"
        gem "activesupport"

        group :rails do
          gem "rails", "2.3.2"
        end
      G

      install_gems "activesupport-2.3.5"

      expect(the_carat).to include_gems "activesupport 2.3.2", :groups => :default
    end

    it "remembers --without and does not bail on bare Carat.setup" do
      install_gemfile <<-G, forgotten_command_line_options(:without => :rails)
        source "file://#{gem_repo1}"
        gem "activesupport"

        group :rails do
          gem "rails", "2.3.2"
        end
      G

      install_gems "activesupport-2.3.5"

      expect(the_carat).to include_gems "activesupport 2.3.2"
    end

    it "remembers --without and does not include groups passed to Carat.setup" do
      install_gemfile <<-G, forgotten_command_line_options(:without => :rails)
        source "file://#{gem_repo1}"
        gem "activesupport"

        group :rack do
          gem "rack"
        end

        group :rails do
          gem "rails", "2.3.2"
        end
      G

      expect(the_carat).not_to include_gems "activesupport 2.3.2", :groups => :rack
      expect(the_carat).to include_gems "rack 1.0.0", :groups => :rack
    end
  end

  # Unfortunately, gem_prelude does not record the information about
  # activated gems, so this test cannot work on 1.9 :(
  if RUBY_VERSION < "1.9"
    describe "preactivated gems" do
      it "raises an exception if a pre activated gem conflicts with the carat" do
        system_gems "thin-1.0", "rack-1.0.0"
        build_gem "thin", "1.1", :to_system => true do |s|
          s.add_dependency "rack"
        end

        gemfile <<-G
          gem "thin", "1.0"
        G

        ruby <<-R
          require 'rubygems'
          gem "thin"
          require 'carat'
          begin
            Carat.setup
            puts "FAIL"
          rescue Gem::LoadError => e
            puts e.message
          end
        R

        expect(out).to eq("You have already activated thin 1.1, but your Gemfile requires thin 1.0. Prepending `carat exec` to your command may solve this.")
      end

      it "version_requirement is now deprecated in rubygems 1.4.0+" do
        system_gems "thin-1.0", "rack-1.0.0"
        build_gem "thin", "1.1", :to_system => true do |s|
          s.add_dependency "rack"
        end

        gemfile <<-G
          gem "thin", "1.0"
        G

        ruby <<-R
          require 'rubygems'
          gem "thin"
          require 'carat'
          begin
            Carat.setup
            puts "FAIL"
          rescue Gem::LoadError => e
            puts e.message
          end
        R

        expect(err).to lack_errors
      end
    end
  end

  # RubyGems returns loaded_from as a string
  it "has loaded_from as a string on all specs" do
    build_git "foo"
    build_git "no-gemspec", :gemspec => false

    install_gemfile <<-G
      source "file://#{gem_repo1}"
      gem "rack"
      gem "foo", :git => "#{lib_path("foo-1.0")}"
      gem "no-gemspec", "1.0", :git => "#{lib_path("no-gemspec-1.0")}"
    G

    run <<-R
      Gem.loaded_specs.each do |n, s|
        puts "FAIL" unless s.loaded_from.is_a?(String)
      end
    R

    expect(out).to be_empty
  end

  it "does not load all gemspecs", :rubygems => ">= 2.3" do
    install_gemfile! <<-G
      source "file://#{gem_repo1}"
      gem "rack"
    G

    run! <<-R
      File.open(File.join(Gem.dir, "specifications", "broken.gemspec"), "w") do |f|
        f.write <<-RUBY
# -*- encoding: utf-8 -*-
# stub: broken 1.0.0 ruby lib

Gem::Specification.new do |s|
  s.name = "broken"
  s.version = "1.0.0"
  raise "BROKEN GEMSPEC"
end
        RUBY
      end
    R

    run! <<-R
      puts "WIN"
    R

    expect(out).to eq("WIN")
  end

  it "ignores empty gem paths" do
    install_gemfile <<-G
      source "file://#{gem_repo1}"
      gem "rack"
    G

    ENV["GEM_HOME"] = ""
    carat %(exec ruby -e "require 'set'")

    expect(err).to lack_errors
  end

  describe "$MANPATH" do
    before do
      build_repo4 do
        build_gem "with_man" do |s|
          s.write("man/man1/page.1", "MANPAGE")
        end
      end
    end

    context "when the user has one set" do
      before { ENV["MANPATH"] = "/foo:" }

      it "adds the gem's man dir to the MANPATH" do
        install_gemfile! <<-G
          source "file:#{gem_repo4}"
          gem "with_man"
        G

        run! "puts ENV['MANPATH']"
        expect(out).to eq("#{default_carat_path("gems/with_man-1.0/man")}:/foo")
      end
    end

    context "when the user does not have one set" do
      before { ENV.delete("MANPATH") }

      it "adds the gem's man dir to the MANPATH" do
        install_gemfile! <<-G
          source "file:#{gem_repo4}"
          gem "with_man"
        G

        run! "puts ENV['MANPATH']"
        expect(out).to eq(default_carat_path("gems/with_man-1.0/man").to_s)
      end
    end
  end

  it "should prepend gemspec require paths to $LOAD_PATH in order" do
    update_repo2 do
      build_gem("requirepaths") do |s|
        s.write("lib/rq.rb", "puts 'yay'")
        s.write("src/rq.rb", "puts 'nooo'")
        s.require_paths = %w[lib src]
      end
    end

    install_gemfile <<-G
      source "file://#{gem_repo2}"
      gem "requirepaths", :require => nil
    G

    run "require 'rq'"
    expect(out).to eq("yay")
  end

  it "should clean $LOAD_PATH properly" do
    gem_name = "very_simple_binary"
    full_gem_name = gem_name + "-1.0"
    ext_dir = File.join(tmp("extenstions", full_gem_name))

    install_gem full_gem_name

    install_gemfile <<-G
      source "file://#{gem_repo1}"
    G

    ruby <<-R
      if Gem::Specification.method_defined? :extension_dir
        s = Gem::Specification.find_by_name '#{gem_name}'
        s.extension_dir = '#{ext_dir}'

        # Don't build extensions.
        s.class.send(:define_method, :build_extensions) { nil }
      end

      require 'carat'
      gem '#{gem_name}'

      puts $LOAD_PATH.count {|path| path =~ /#{gem_name}/} >= 2

      Carat.setup

      puts $LOAD_PATH.count {|path| path =~ /#{gem_name}/} == 0
    R

    expect(out).to eq("true\ntrue")
  end

  it "stubs out Gem.refresh so it does not reveal system gems" do
    system_gems "rack-1.0.0"

    install_gemfile <<-G
      source "file://#{gem_repo1}"
      gem "activesupport"
    G

    run <<-R
      puts Carat.rubygems.find_name("rack").inspect
      Gem.refresh
      puts Carat.rubygems.find_name("rack").inspect
    R

    expect(out).to eq("[]\n[]")
  end

  describe "when a vendored gem specification uses the :path option" do
    it "should resolve paths relative to the Gemfile" do
      path = carated_app(File.join("vendor", "foo"))
      build_lib "foo", :path => path

      # If the .gemspec exists, then Carat handles the path differently.
      # See Source::Path.load_spec_files for details.
      FileUtils.rm(File.join(path, "foo.gemspec"))

      install_gemfile <<-G
        gem 'foo', '1.2.3', :path => 'vendor/foo'
      G

      Dir.chdir(carated_app.parent) do
        run <<-R, :env => { "CARAT_GEMFILE" => carated_app("Gemfile") }
          require 'foo'
        R
      end
      expect(err).to lack_errors
    end

    it "should make sure the Carat.root is really included in the path relative to the Gemfile" do
      relative_path = File.join("vendor", Dir.pwd[1..-1], "foo")
      absolute_path = carated_app(relative_path)
      FileUtils.mkdir_p(absolute_path)
      build_lib "foo", :path => absolute_path

      # If the .gemspec exists, then Carat handles the path differently.
      # See Source::Path.load_spec_files for details.
      FileUtils.rm(File.join(absolute_path, "foo.gemspec"))

      gemfile <<-G
        gem 'foo', '1.2.3', :path => '#{relative_path}'
      G

      carat :install

      Dir.chdir(carated_app.parent) do
        run <<-R, :env => { "CARAT_GEMFILE" => carated_app("Gemfile") }
          require 'foo'
        R
      end

      expect(err).to lack_errors
    end
  end

  describe "with git gems that don't have gemspecs" do
    before :each do
      build_git "no-gemspec", :gemspec => false

      install_gemfile <<-G
        gem "no-gemspec", "1.0", :git => "#{lib_path("no-gemspec-1.0")}"
      G
    end

    it "loads the library via a virtual spec" do
      run <<-R
        require 'no-gemspec'
        puts NOGEMSPEC
      R

      expect(out).to eq("1.0")
    end
  end

  describe "with carated and system gems" do
    before :each do
      system_gems "rack-1.0.0"

      install_gemfile <<-G
        source "file://#{gem_repo1}"

        gem "activesupport", "2.3.5"
      G
    end

    it "does not pull in system gems" do
      run <<-R
        require 'rubygems'

        begin;
          require 'rack'
        rescue LoadError
          puts 'WIN'
        end
      R

      expect(out).to eq("WIN")
    end

    it "provides a gem method" do
      run <<-R
        gem 'activesupport'
        require 'activesupport'
        puts ACTIVESUPPORT
      R

      expect(out).to eq("2.3.5")
    end

    it "raises an exception if gem is used to invoke a system gem not in the carat" do
      run <<-R
        begin
          gem 'rack'
        rescue LoadError => e
          puts e.message
        end
      R

      expect(out).to eq("rack is not part of the carat. Add it to your Gemfile.")
    end

    it "sets GEM_HOME appropriately" do
      run "puts ENV['GEM_HOME']"
      expect(out).to eq(default_carat_path.to_s)
    end
  end

  describe "with system gems in the carat" do
    before :each do
      carat! "config path.system true"
      system_gems "rack-1.0.0"

      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack", "1.0.0"
        gem "activesupport", "2.3.5"
      G
    end

    it "sets GEM_PATH appropriately" do
      run "puts Gem.path"
      paths = out.split("\n")
      expect(paths).to include(system_gem_path.to_s)
    end
  end

  describe "with a gemspec that requires other files" do
    before :each do
      build_git "bar", :gemspec => false do |s|
        s.write "lib/bar/version.rb", %(BAR_VERSION = '1.0')
        s.write "bar.gemspec", <<-G
          lib = File.expand_path('../lib/', __FILE__)
          $:.unshift lib unless $:.include?(lib)
          require 'bar/version'

          Gem::Specification.new do |s|
            s.name        = 'bar'
            s.version     = BAR_VERSION
            s.summary     = 'Bar'
            s.files       = Dir["lib/**/*.rb"]
            s.author      = 'no one'
          end
        G
      end

      gemfile <<-G
        gem "bar", :git => "#{lib_path("bar-1.0")}"
      G
    end

    it "evals each gemspec in the context of its parent directory" do
      carat :install
      run "require 'bar'; puts BAR"
      expect(out).to eq("1.0")
    end

    it "error intelligently if the gemspec has a LoadError" do
      ref = update_git "bar", :gemspec => false do |s|
        s.write "bar.gemspec", "require 'foobarbaz'"
      end.ref_for("HEAD")
      carat :install

      expect(out.lines.map(&:chomp)).to include(
        a_string_starting_with("[!] There was an error while loading `bar.gemspec`:"),
        RUBY_VERSION >= "1.9" ? a_string_starting_with("Does it try to require a relative path? That's been removed in Ruby 1.9.") : "",
        " #  from #{default_carat_path "carat", "gems", "bar-1.0-#{ref[0, 12]}", "bar.gemspec"}:1",
        " >  require 'foobarbaz'"
      )
    end

    it "evals each gemspec with a binding from the top level" do
      carat "install"

      ruby <<-RUBY
        require 'carat'
        def Carat.require(path)
          raise "LOSE"
        end
        Carat.load
      RUBY

      expect(err).to lack_errors
      expect(out).to eq("")
    end
  end

  describe "when Carat is carated" do
    it "doesn't blow up" do
      install_gemfile <<-G
        gem "carat", :path => "#{File.expand_path("..", lib)}"
      G

      carat %(exec ruby -e "require 'carat'; Carat.setup")
      expect(err).to lack_errors
    end
  end

  describe "when CARAT VERSION" do
    def lock_with(carat_version = nil)
      lock = <<-L
        GEM
          remote: file:#{gem_repo1}/
          specs:
            rack (1.0.0)

        PLATFORMS
          #{lockfile_platforms}

        DEPENDENCIES
          rack
      L

      if carat_version
        lock += "\n        CARAT VERSION\n           #{carat_version}\n"
      end

      lock
    end

    before do
      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"
      G
    end

    context "is not present" do
      it "does not change the lock" do
        lockfile lock_with(nil)
        ruby "require 'carat/setup'"
        lockfile_should_be lock_with(nil)
      end
    end

    context "is newer" do
      it "does not change the lock or warn" do
        lockfile lock_with(Carat::VERSION.succ)
        ruby "require 'carat/setup'"
        expect(out).to eq("")
        expect(err).to eq("")
        lockfile_should_be lock_with(Carat::VERSION.succ)
      end
    end

    context "is older" do
      it "does not change the lock" do
        lockfile lock_with("1.10.1")
        ruby "require 'carat/setup'"
        lockfile_should_be lock_with("1.10.1")
      end
    end
  end

  describe "when RUBY VERSION" do
    let(:ruby_version) { nil }

    def lock_with(ruby_version = nil)
      lock = <<-L
        GEM
          remote: file:#{gem_repo1}/
          specs:
            rack (1.0.0)

        PLATFORMS
          #{lockfile_platforms}

        DEPENDENCIES
          rack
      L

      if ruby_version
        lock += "\n        RUBY VERSION\n           ruby #{ruby_version}\n"
      end

      lock += <<-L

        CARAT VERSION
           #{Carat::VERSION}
      L

      lock
    end

    before do
      install_gemfile <<-G
        ruby ">= 0"
        source "file:#{gem_repo1}"
        gem "rack"
      G
      lockfile lock_with(ruby_version)
    end

    context "is not present" do
      it "does not change the lock" do
        expect { ruby! "require 'carat/setup'" }.not_to change { lockfile }
      end
    end

    context "is newer" do
      let(:ruby_version) { "5.5.5" }
      it "does not change the lock or warn" do
        expect { ruby! "require 'carat/setup'" }.not_to change { lockfile }
        expect(out).to eq("")
        expect(err).to eq("")
      end
    end

    context "is older" do
      let(:ruby_version) { "1.0.0" }
      it "does not change the lock" do
        expect { ruby! "require 'carat/setup'" }.not_to change { lockfile }
      end
    end
  end

  describe "with gemified standard libraries" do
    it "does not load Psych", :ruby => "~> 2.2" do
      gemfile ""
      ruby <<-RUBY
        require 'carat/setup'
        puts defined?(Psych::VERSION) ? Psych::VERSION : "undefined"
        require 'psych'
        puts Psych::VERSION
      RUBY
      pre_carat, post_carat = out.split("\n")
      expect(pre_carat).to eq("undefined")
      expect(post_carat).to match(/\d+\.\d+\.\d+/)
    end

    it "does not load openssl" do
      install_gemfile! ""
      ruby! <<-RUBY
        require "carat/setup"
        puts defined?(OpenSSL) || "undefined"
        require "openssl"
        puts defined?(OpenSSL) || "undefined"
      RUBY
      expect(out).to eq("undefined\nconstant")
    end

    describe "default gem activation" do
      let(:exemptions) do
        if Gem::Version.new(Gem::VERSION) >= Gem::Version.new("2.7") || ENV["RGV"] == "master"
          []
        else
          %w[io-console openssl]
        end << "carat"
      end

      let(:activation_warning_hack) { strip_whitespace(<<-RUBY) }
        require "rubygems"

        if Gem::Specification.instance_methods.map(&:to_sym).include?(:activate)
          Gem::Specification.send(:alias_method, :carat_spec_activate, :activate)
          Gem::Specification.send(:define_method, :activate) do
            unless #{exemptions.inspect}.include?(name)
              warn '-' * 80
              warn "activating \#{full_name}"
              warn *caller
              warn '*' * 80
            end
            carat_spec_activate
          end
        end
      RUBY

      let(:activation_warning_hack_rubyopt) do
        create_file("activation_warning_hack.rb", activation_warning_hack)
        "-r#{carated_app("activation_warning_hack.rb")} #{ENV["RUBYOPT"]}"
      end

      let(:code) { strip_whitespace(<<-RUBY) }
        require "carat/setup"
        require "pp"
        loaded_specs = Gem.loaded_specs.dup
        #{exemptions.inspect}.each {|s| loaded_specs.delete(s) }
        pp loaded_specs

        # not a default gem, but harmful to have loaded
        open_uri = $LOADED_FEATURES.grep(/open.uri/)
        unless open_uri.empty?
          warn "open_uri: \#{open_uri}"
        end
      RUBY

      it "activates no gems with -rcarat/setup" do
        install_gemfile! ""
        ruby! code, :env => { :RUBYOPT => activation_warning_hack_rubyopt }
        expect(last_command.stdout).to eq("{}")
      end

      it "activates no gems with carat exec" do
        install_gemfile! ""
        create_file("script.rb", code)
        carat! "exec ruby ./script.rb", :env => { :RUBYOPT => activation_warning_hack_rubyopt }
        expect(last_command.stdout).to eq("{}")
      end

      it "activates no gems with carat exec that is loaded" do
        # TODO: remove once https://github.com/erikhuda/thor/pull/539 is released
        exemptions << "io-console"

        install_gemfile! ""
        create_file("script.rb", "#!/usr/bin/env ruby\n\n#{code}")
        FileUtils.chmod(0o777, carated_app("script.rb"))
        carat! "exec ./script.rb", :artifice => nil, :env => { :RUBYOPT => activation_warning_hack_rubyopt }
        expect(last_command.stdout).to eq("{}")
      end

      let(:default_gems) do
        ruby!(<<-RUBY).split("\n")
          if Gem::Specification.is_a?(Enumerable)
            puts Gem::Specification.select(&:default_gem?).map(&:name)
          end
        RUBY
      end

      it "activates newer versions of default gems" do
        build_repo4 do
          default_gems.each do |g|
            build_gem g, "999999"
          end
        end

        default_gems.reject! {|g| exemptions.include?(g) }

        install_gemfile! <<-G
          source "file:#{gem_repo4}"
          #{default_gems}.each do |g|
            gem g, "999999"
          end
        G

        expect(the_carat).to include_gems(*default_gems.map {|g| "#{g} 999999" })
      end

      it "activates older versions of default gems" do
        build_repo4 do
          default_gems.each do |g|
            build_gem g, "0.0.0.a"
          end
        end

        default_gems.reject! {|g| exemptions.include?(g) }

        install_gemfile! <<-G
          source "file:#{gem_repo4}"
          #{default_gems}.each do |g|
            gem g, "0.0.0.a"
          end
        G

        expect(the_carat).to include_gems(*default_gems.map {|g| "#{g} 0.0.0.a" })
      end
    end
  end

  describe "after setup" do
    it "allows calling #gem on random objects", :carat => "< 2" do
      install_gemfile <<-G
        source "file:#{gem_repo1}"
        gem "rack"
      G

      ruby! <<-RUBY
        require "carat/setup"
        Object.new.gem "rack"
        puts Gem.loaded_specs["rack"].full_name
      RUBY

      expect(out).to eq("rack-1.0.0")
    end

    it "keeps Kernel#gem private", :carat => "2" do
      install_gemfile! <<-G
        source "file:#{gem_repo1}"
        gem "rack"
      G

      ruby <<-RUBY
        require "carat/setup"
        Object.new.gem "rack"
        puts "FAIL"
      RUBY

      expect(last_command.stdboth).not_to include "FAIL"
      expect(last_command.stderr).to include "private method `gem'"
    end

    it "keeps Kernel#require private" do
      install_gemfile! <<-G
        source "file:#{gem_repo1}"
        gem "rack"
      G

      ruby <<-RUBY
        require "carat/setup"
        Object.new.require "rack"
        puts "FAIL"
      RUBY

      expect(last_command.stdboth).not_to include "FAIL"
      expect(last_command.stderr).to include "private method `require'"
    end
  end
end
