require "spec_helper"

describe "git base name" do
  it "base_name should strip private repo uris" do
    source  = Carat::Source::Git.new("uri" => "git@github.com:carat.git")
    expect(source.send(:base_name)).to eq("carat")
  end

  it "base_name should strip network share paths" do
    source = Carat::Source::Git.new("uri" => "//MachineName/ShareFolder")
    expect(source.send(:base_name)).to eq("ShareFolder")
  end
end

%w(cache package).each do |cmd|
  describe "carat #{cmd} with git" do
    it "copies repository to vendor cache and uses it" do
      git = build_git "foo"
      ref = git.ref_for("master", 11)

      install_gemfile <<-G
        gem "foo", :git => '#{lib_path("foo-1.0")}'
      G

      carat "#{cmd} --all"
      expect(bundled_app("vendor/cache/foo-1.0-#{ref}")).to exist
      expect(bundled_app("vendor/cache/foo-1.0-#{ref}/.git")).not_to exist
      expect(bundled_app("vendor/cache/foo-1.0-#{ref}/.caratcache")).to be_file

      FileUtils.rm_rf lib_path("foo-1.0")
      should_be_installed "foo 1.0"
    end

    it "copies repository to vendor cache and uses it even when installed with carat --path" do
      git = build_git "foo"
      ref = git.ref_for("master", 11)

      install_gemfile <<-G
        gem "foo", :git => '#{lib_path("foo-1.0")}'
      G

      carat "install --path vendor/bundle"
      carat "#{cmd} --all"

      expect(bundled_app("vendor/cache/foo-1.0-#{ref}")).to exist
      expect(bundled_app("vendor/cache/foo-1.0-#{ref}/.git")).not_to exist

      FileUtils.rm_rf lib_path("foo-1.0")
      should_be_installed "foo 1.0"
    end

    it "runs twice without exploding" do
      build_git "foo"

      install_gemfile <<-G
        gem "foo", :git => '#{lib_path("foo-1.0")}'
      G

      carat "#{cmd} --all"
      carat "#{cmd} --all"

      expect(err).to eq("")
      FileUtils.rm_rf lib_path("foo-1.0")
      should_be_installed "foo 1.0"
    end

    it "tracks updates" do
      git = build_git "foo"
      old_ref = git.ref_for("master", 11)

      install_gemfile <<-G
        gem "foo", :git => '#{lib_path("foo-1.0")}'
      G

      carat "#{cmd} --all"

      update_git "foo" do |s|
        s.write "lib/foo.rb", "puts :CACHE"
      end

      ref = git.ref_for("master", 11)
      expect(ref).not_to eq(old_ref)

      carat "update"
      carat "#{cmd} --all"

      expect(bundled_app("vendor/cache/foo-1.0-#{ref}")).to exist
      expect(bundled_app("vendor/cache/foo-1.0-#{old_ref}")).not_to exist

      FileUtils.rm_rf lib_path("foo-1.0")
      run "require 'foo'"
      expect(out).to eq("CACHE")
    end

    it "uses the local repository to generate the cache" do
      git = build_git "foo"
      ref = git.ref_for("master", 11)

      gemfile <<-G
        gem "foo", :git => '#{lib_path("foo-invalid")}', :branch => :master
      G

      carat %|config local.foo #{lib_path('foo-1.0')}|
      carat "install"
      carat "#{cmd} --all"

      expect(bundled_app("vendor/cache/foo-invalid-#{ref}")).to exist

      # Updating the local still uses the local.
      update_git "foo" do |s|
        s.write "lib/foo.rb", "puts :LOCAL"
      end

      run "require 'foo'"
      expect(out).to eq("LOCAL")
    end

    it "copies repository to vendor cache, including submodules" do
      build_git "submodule", "1.0"

      git = build_git "has_submodule", "1.0" do |s|
        s.add_dependency "submodule"
      end

      Dir.chdir(lib_path('has_submodule-1.0')) do
        `git submodule add #{lib_path('submodule-1.0')} submodule-1.0`
        `git commit -m "submodulator"`
      end

      install_gemfile <<-G
        git "#{lib_path('has_submodule-1.0')}", :submodules => true do
          gem "has_submodule"
        end
      G

      ref = git.ref_for("master", 11)
      carat "#{cmd} --all"

      expect(bundled_app("vendor/cache/has_submodule-1.0-#{ref}")).to exist
      expect(bundled_app("vendor/cache/has_submodule-1.0-#{ref}/submodule-1.0")).to exist
      should_be_installed "has_submodule 1.0"
    end

    it "displays warning message when detecting git repo in Gemfile" do
      build_git "foo"

      install_gemfile <<-G
        gem "foo", :git => '#{lib_path("foo-1.0")}'
      G

      carat "#{cmd}"

      expect(out).to include("Your Gemfile contains path and git dependencies.")
    end

    it "does not display warning message if cache_all is set in carat config" do
      build_git "foo"

      install_gemfile <<-G
        gem "foo", :git => '#{lib_path("foo-1.0")}'
      G

      carat "#{cmd} --all"
      carat "#{cmd}"

      expect(out).not_to include("Your Gemfile contains path and git dependencies.")
    end

    it "caches pre-evaluated gemspecs" do
      git = build_git "foo"

      # Insert a gemspec method that shells out
      spec_lines = lib_path("foo-1.0/foo.gemspec").read.split("\n")
      spec_lines.insert(-2, "s.description = `echo bob`")
      update_git("foo"){ |s| s.write "foo.gemspec", spec_lines.join("\n") }

      install_gemfile <<-G
        gem "foo", :git => '#{lib_path("foo-1.0")}'
      G
      carat "#{cmd} --all"

      ref = git.ref_for("master", 11)
      gemspec = bundled_app("vendor/cache/foo-1.0-#{ref}/foo.gemspec").read
      expect(gemspec).to_not match("`echo bob`")
    end

  end
end
