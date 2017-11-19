require "spec_helper"

describe ".carat/config" do
  before :each do
    gemfile <<-G
      source "file://#{gem_repo1}"
      gem "rack", "1.0.0"
    G
  end

  describe "BUNDLE_APP_CONFIG" do
    it "can be moved with an environment variable" do
      ENV['BUNDLE_APP_CONFIG'] = tmp('foo/bar').to_s
      carat "install --path vendor/bundle"

      expect(bundled_app('.carat')).not_to exist
      expect(tmp('foo/bar/config')).to exist
      should_be_installed "rack 1.0.0"
    end

    it "can provide a relative path with the environment variable" do
      FileUtils.mkdir_p bundled_app('omg')
      Dir.chdir bundled_app('omg')

      ENV['BUNDLE_APP_CONFIG'] = "../foo"
      carat "install --path vendor/bundle"

      expect(bundled_app(".carat")).not_to exist
      expect(bundled_app("../foo/config")).to exist
      should_be_installed "rack 1.0.0"
    end

    it "removes environment.rb from BUNDLE_APP_CONFIG's path" do
      FileUtils.mkdir_p(tmp('foo/bar'))
      ENV['BUNDLE_APP_CONFIG'] = tmp('foo/bar').to_s
      carat "install"
      FileUtils.touch tmp('foo/bar/environment.rb')
      should_be_installed "rack 1.0.0"
      expect(tmp('foo/bar/environment.rb')).not_to exist
    end
  end

  describe "global" do
    before(:each) { carat :install }

    it "is the default" do
      carat "config foo global"
      run "puts Carat.settings[:foo]"
      expect(out).to eq("global")
    end

    it "can also be set explicitly" do
      carat "config --global foo global"
      run "puts Carat.settings[:foo]"
      expect(out).to eq("global")
    end

    it "has lower precedence than local" do
      carat "config --local  foo local"

      carat "config --global foo global"
      expect(out).to match(/Your application has set foo to "local"/)

      run "puts Carat.settings[:foo]"
      expect(out).to eq("local")
    end

    it "has lower precedence than env" do
      begin
        ENV["BUNDLE_FOO"] = "env"

        carat "config --global foo global"
        expect(out).to match(/You have a carat environment variable for foo set to "env"/)

        run "puts Carat.settings[:foo]"
        expect(out).to eq("env")
      ensure
        ENV.delete("BUNDLE_FOO")
      end
    end

    it "can be deleted" do
      carat "config --global foo global"
      carat "config --delete foo"

      run "puts Carat.settings[:foo] == nil"
      expect(out).to eq("true")
    end

    it "warns when overriding" do
      carat "config --global foo previous"
      carat "config --global foo global"
      expect(out).to match(/You are replacing the current global value of foo/)

      run "puts Carat.settings[:foo]"
      expect(out).to eq("global")
    end

    it "expands the path at time of setting" do
      carat "config --global local.foo .."
      run "puts Carat.settings['local.foo']"
      expect(out).to eq(File.expand_path(Dir.pwd + "/.."))
    end
  end

  describe "local" do
    before(:each) { carat :install }

    it "can also be set explicitly" do
      carat "config --local foo local"
      run "puts Carat.settings[:foo]"
      expect(out).to eq("local")
    end

    it "has higher precedence than env" do
      begin
        ENV["BUNDLE_FOO"] = "env"
        carat "config --local foo local"

        run "puts Carat.settings[:foo]"
        expect(out).to eq("local")
      ensure
        ENV.delete("BUNDLE_FOO")
      end
    end

    it "can be deleted" do
      carat "config --local foo local"
      carat "config --delete foo"

      run "puts Carat.settings[:foo] == nil"
      expect(out).to eq("true")
    end

    it "warns when overriding" do
      carat "config --local foo previous"
      carat "config --local foo local"
      expect(out).to match(/You are replacing the current local value of foo/)

      run "puts Carat.settings[:foo]"
      expect(out).to eq("local")
    end

    it "expands the path at time of setting" do
      carat "config --local local.foo .."
      run "puts Carat.settings['local.foo']"
      expect(out).to eq(File.expand_path(Dir.pwd + "/.."))
    end
  end

  describe "env" do
    before(:each) { carat :install }

    it "can set boolean properties via the environment" do
      ENV["BUNDLE_FROZEN"] = "true"

      run "if Carat.settings[:frozen]; puts 'true' else puts 'false' end"
      expect(out).to eq("true")
    end

    it "can set negative boolean properties via the environment" do
      run "if Carat.settings[:frozen]; puts 'true' else puts 'false' end"
      expect(out).to eq("false")

      ENV["BUNDLE_FROZEN"] = "false"

      run "if Carat.settings[:frozen]; puts 'true' else puts 'false' end"
      expect(out).to eq("false")

      ENV["BUNDLE_FROZEN"] = "0"

      run "if Carat.settings[:frozen]; puts 'true' else puts 'false' end"
      expect(out).to eq("false")

      ENV["BUNDLE_FROZEN"] = ""

      run "if Carat.settings[:frozen]; puts 'true' else puts 'false' end"
      expect(out).to eq("false")
    end

    it "can set properties with periods via the environment" do
      ENV["BUNDLE_FOO__BAR"] = "baz"

      run "puts Carat.settings['foo.bar']"
      expect(out).to eq("baz")
     end
  end

  describe "gem mirrors" do
    before(:each) { carat :install }

    it "configures mirrors using keys with `mirror.`" do
      carat "config --local mirror.http://gems.example.org http://gem-mirror.example.org"
      run(<<-E)
Carat.settings.gem_mirrors.each do |k, v|
  puts "\#{k} => \#{v}"
end
E
      expect(out).to eq("http://gems.example.org/ => http://gem-mirror.example.org/")
    end
  end

  describe "quoting" do
    before(:each) { gemfile "# no gems" }
    let(:long_string) do
      "--with-xml2-include=/usr/pkg/include/libxml2 --with-xml2-lib=/usr/pkg/lib " \
      "--with-xslt-dir=/usr/pkg"
    end

    it "saves quotes" do
      carat "config foo something\\'"
      run "puts Carat.settings[:foo]"
      expect(out).to eq("something'")
    end

    it "doesn't return quotes around values", :ruby => "1.9" do
      carat "config foo '1'"
      run "puts Carat.settings.send(:global_config_file).read"
      expect(out).to include("'1'")
      run "puts Carat.settings[:foo]"
      expect(out).to eq("1")
    end

    it "doesn't duplicate quotes around values", :if => (RUBY_VERSION >= "2.1") do
      bundled_app(".carat").mkpath
      File.open(bundled_app(".carat/config"), 'w') do |f|
        f.write 'BUNDLE_FOO: "$BUILD_DIR"'
      end

      carat "config bar baz"
      run "puts Carat.settings.send(:local_config_file).read"

      # Starting in Ruby 2.1, YAML automatically adds double quotes
      # around some values, including $ and newlines.
      expect(out).to include('BUNDLE_FOO: "$BUILD_DIR"')
    end

    it "doesn't duplicate quotes around long wrapped values" do
      carat "config foo #{long_string}"

      run "puts Carat.settings[:foo]"
      expect(out).to eq(long_string)

      carat "config bar baz"

      run "puts Carat.settings[:foo]"
      expect(out).to eq(long_string)
    end
  end

  describe "very long lines" do
    before(:each) { carat :install }
    let(:long_string) do
      "--with-xml2-include=/usr/pkg/include/libxml2 --with-xml2-lib=/usr/pkg/lib " \
      "--with-xslt-dir=/usr/pkg"
    end
    let(:long_string_without_special_characters) do
      "here is quite a long string that will wrap to a second line but will not be " \
      "surrounded by quotes"
    end
    let(:long_string_without_special_characters) do
      "here is quite a long string that will wrap to a second line but will not be surrounded by quotes"
    end

    it "doesn't wrap values" do
      carat "config foo #{long_string}"
      run "puts Carat.settings[:foo]"
      expect(out).to match(long_string)
    end

    it "can read wrapped unquoted values" do
      carat "config foo #{long_string_without_special_characters}"
      run "puts Carat.settings[:foo]"
      expect(out).to match(long_string_without_special_characters)
    end
  end
end

describe "setting gemfile via config" do
  context "when only the non-default Gemfile exists" do
    it "persists the gemfile location to .carat/config" do
      File.open(bundled_app("NotGemfile"), "w") do |f|
        f.write <<-G
          source "file://#{gem_repo1}"
          gem 'rack'
        G
      end

      carat "config --local gemfile #{bundled_app("NotGemfile")}"
      expect(File.exist?(".carat/config")).to eq(true)

      carat "config"
      expect(out).to include("NotGemfile")
    end
  end
end
