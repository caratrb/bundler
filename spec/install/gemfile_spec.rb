require "spec_helper"

describe "carat install" do

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
      gemfile bundled_app("NotGemfile"), <<-G
        source "file://#{gem_repo1}"
        gem 'rack'
      G

      carat :install, :gemfile => bundled_app("NotGemfile")

      ENV['BUNDLE_GEMFILE'] = "NotGemfile"
      should_be_installed "rack 1.0.0"
    end
  end

  context "with gemfile set via config" do
    before do
      gemfile bundled_app("NotGemfile"), <<-G
        source "file://#{gem_repo1}"
        gem 'rack'
      G

      carat "config --local gemfile #{bundled_app("NotGemfile")}"
    end
    it "uses the gemfile to install" do
      carat "install"
      carat "show"

      expect(out).to include("rack (1.0.0)")
    end
    it "uses the gemfile while in a subdirectory" do
      bundled_app("subdir").mkpath
      Dir.chdir(bundled_app("subdir")) do
        carat "install"
        carat "show"

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

end
