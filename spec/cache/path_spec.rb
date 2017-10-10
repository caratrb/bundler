# frozen_string_literal: true

%w[cache package].each do |cmd|
  RSpec.describe "carat #{cmd} with path" do
    it "is no-op when the path is within the carat" do
      build_lib "foo", :path => carated_app("lib/foo")

      install_gemfile <<-G
        gem "foo", :path => '#{carated_app("lib/foo")}'
      G

      carat cmd, forgotten_command_line_options([:all, :cache_all] => true)
      expect(carated_app("vendor/cache/foo-1.0")).not_to exist
      expect(the_carat).to include_gems "foo 1.0"
    end

    it "copies when the path is outside the carat " do
      build_lib "foo"

      install_gemfile <<-G
        gem "foo", :path => '#{lib_path("foo-1.0")}'
      G

      carat cmd, forgotten_command_line_options([:all, :cache_all] => true)
      expect(carated_app("vendor/cache/foo-1.0")).to exist
      expect(carated_app("vendor/cache/foo-1.0/.caratcache")).to be_file

      FileUtils.rm_rf lib_path("foo-1.0")
      expect(the_carat).to include_gems "foo 1.0"
    end

    it "copies when the path is outside the carat and the paths intersect" do
      libname = File.basename(Dir.pwd) + "_gem"
      libpath = File.join(File.dirname(Dir.pwd), libname)

      build_lib libname, :path => libpath

      install_gemfile <<-G
        gem "#{libname}", :path => '#{libpath}'
      G

      carat cmd, forgotten_command_line_options([:all, :cache_all] => true)
      expect(carated_app("vendor/cache/#{libname}")).to exist
      expect(carated_app("vendor/cache/#{libname}/.caratcache")).to be_file

      FileUtils.rm_rf libpath
      expect(the_carat).to include_gems "#{libname} 1.0"
    end

    it "updates the path on each cache" do
      build_lib "foo"

      install_gemfile <<-G
        gem "foo", :path => '#{lib_path("foo-1.0")}'
      G

      carat cmd, forgotten_command_line_options([:all, :cache_all] => true)

      build_lib "foo" do |s|
        s.write "lib/foo.rb", "puts :CACHE"
      end

      carat cmd, forgotten_command_line_options([:all, :cache_all] => true)

      expect(carated_app("vendor/cache/foo-1.0")).to exist
      FileUtils.rm_rf lib_path("foo-1.0")

      run "require 'foo'"
      expect(out).to eq("CACHE")
    end

    it "removes stale entries cache" do
      build_lib "foo"

      install_gemfile <<-G
        gem "foo", :path => '#{lib_path("foo-1.0")}'
      G

      carat cmd, forgotten_command_line_options([:all, :cache_all] => true)

      install_gemfile <<-G
        gem "bar", :path => '#{lib_path("bar-1.0")}'
      G

      carat cmd, forgotten_command_line_options([:all, :cache_all] => true)
      expect(carated_app("vendor/cache/bar-1.0")).not_to exist
    end

    it "raises a warning without --all", :carat => "< 2" do
      build_lib "foo"

      install_gemfile <<-G
        gem "foo", :path => '#{lib_path("foo-1.0")}'
      G

      carat cmd
      expect(out).to match(/please pass the \-\-all flag/)
      expect(carated_app("vendor/cache/foo-1.0")).not_to exist
    end

    it "stores the given flag" do
      build_lib "foo"

      install_gemfile <<-G
        gem "foo", :path => '#{lib_path("foo-1.0")}'
      G

      carat cmd, forgotten_command_line_options([:all, :cache_all] => true)
      build_lib "bar"

      install_gemfile <<-G
        gem "foo", :path => '#{lib_path("foo-1.0")}'
        gem "bar", :path => '#{lib_path("bar-1.0")}'
      G

      carat cmd
      expect(carated_app("vendor/cache/bar-1.0")).to exist
    end

    it "can rewind chosen configuration" do
      build_lib "foo"

      install_gemfile <<-G
        gem "foo", :path => '#{lib_path("foo-1.0")}'
      G

      carat cmd, forgotten_command_line_options([:all, :cache_all] => true)
      build_lib "baz"

      gemfile <<-G
        gem "foo", :path => '#{lib_path("foo-1.0")}'
        gem "baz", :path => '#{lib_path("baz-1.0")}'
      G

      carat "#{cmd} --no-all"
      expect(carated_app("vendor/cache/baz-1.0")).not_to exist
    end
  end
end
