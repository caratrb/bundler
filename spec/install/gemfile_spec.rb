# frozen_string_literal: true

RSpec.describe "carat install" do
  context "with duplicated gems" do
    it "will display a warning" do
      install_gemfile <<-G
        gem 'rails', '~> 4.0.0'
        gem 'rails', '~> 4.0.0'
      G
      expect(out).to include("more than once")
    end
  end

  context "with --gemfile" do
    it "finds the gemfile" do
      gemfile carated_app("NotGemfile"), <<-G
        source "file://#{gem_repo1}"
        gem 'rack'
      G

      carat :install, :gemfile => carated_app("NotGemfile")

      ENV["CARAT_GEMFILE"] = "NotGemfile"
      expect(the_carat).to include_gems "rack 1.0.0"
    end
  end

  context "with gemfile set via config" do
    before do
      gemfile carated_app("NotGemfile"), <<-G
        source "file://#{gem_repo1}"
        gem 'rack'
      G

      carat "config --local gemfile #{carated_app("NotGemfile")}"
    end
    it "uses the gemfile to install" do
      carat "install"
      carat "list"

      expect(out).to include("rack (1.0.0)")
    end
    it "uses the gemfile while in a subdirectory" do
      carated_app("subdir").mkpath
      Dir.chdir(carated_app("subdir")) do
        carat "install"
        carat "list"

        expect(out).to include("rack (1.0.0)")
      end
    end
  end

  context "with deprecated features" do
    before :each do
      in_app_root
    end

    it "reports that lib is an invalid option" do
      gemfile <<-G
        gem "rack", :lib => "rack"
      G

      carat :install
      expect(out).to match(/You passed :lib as an option for gem 'rack', but it is invalid/)
    end
  end

  context "with prefer_gems_rb set" do
    before { carat! "config prefer_gems_rb true" }

    it "prefers gems.rb to Gemfile" do
      create_file("gems.rb", "gem 'carat'")
      create_file("Gemfile", "raise 'wrong Gemfile!'")

      carat! :install

      expect(carated_app("gems.rb")).to be_file
      expect(carated_app("Gemfile.lock")).not_to be_file

      expect(the_carat).to include_gem "carat #{Carat::VERSION}"
    end
  end

  context "with engine specified in symbol" do
    it "does not raise any error parsing Gemfile" do
      simulate_ruby_version "2.3.0" do
        simulate_ruby_engine "jruby", "9.1.2.0" do
          install_gemfile! <<-G
            source "file://#{gem_repo1}"
            ruby "2.3.0", :engine => :jruby, :engine_version => "9.1.2.0"
          G

          expect(out).to match(/Carat complete!/)
        end
      end
    end

    it "installation succeeds" do
      simulate_ruby_version "2.3.0" do
        simulate_ruby_engine "jruby", "9.1.2.0" do
          install_gemfile! <<-G
            source "file://#{gem_repo1}"
            ruby "2.3.0", :engine => :jruby, :engine_version => "9.1.2.0"
            gem "rack"
          G

          expect(the_carat).to include_gems "rack 1.0.0"
        end
      end
    end
  end
end
