# frozen_string_literal: true

RSpec.describe "major deprecations", :carat => "< 2" do
  let(:warnings) { last_command.carat_err } # change to err in 2.0
  let(:warnings_without_version_messages) { warnings.gsub(/#{Spec::Matchers::MAJOR_DEPRECATION}Carat will only support ruby(gems)? >= .*/, "") }

  context "in a .99 version" do
    before do
      simulate_carat_version "1.99.1"
      carat "config --delete major_deprecations"
    end

    it "prints major deprecations without being configured" do
      ruby <<-R
        require "carat"
        Carat::SharedHelpers.major_deprecation(Carat::VERSION)
      R

      expect(warnings).to have_major_deprecation("1.99.1")
    end
  end

  before do
    carat "config major_deprecations true"

    create_file "gems.rb", <<-G
      source "file:#{gem_repo1}"
      ruby #{RUBY_VERSION.dump}
      gem "rack"
    G
    carat! "install"
  end

  describe "carat_ruby" do
    it "prints a deprecation" do
      carat_ruby
      warnings.gsub! "\nruby #{RUBY_VERSION}", ""
      expect(warnings).to have_major_deprecation "the carat_ruby executable has been removed in favor of `carat platform --ruby`"
    end
  end

  describe "Carat" do
    describe ".clean_env" do
      it "is deprecated in favor of .original_env" do
        source = "Carat.clean_env"
        carat "exec ruby -e #{source.dump}"
        expect(warnings).to have_major_deprecation "`Carat.clean_env` has weird edge cases, use `.original_env` instead"
      end
    end

    describe ".environment" do
      it "is deprecated in favor of .load" do
        source = "Carat.environment"
        carat "exec ruby -e #{source.dump}"
        expect(warnings).to have_major_deprecation "Carat.environment has been removed in favor of Carat.load"
      end
    end

    shared_examples_for "environmental deprecations" do |trigger|
      describe "ruby version", :ruby => "< 2.0" do
        it "requires a newer ruby version" do
          instance_eval(&trigger)
          expect(warnings).to have_major_deprecation "Carat will only support ruby >= 2.0, you are running #{RUBY_VERSION}"
        end
      end

      describe "rubygems version", :rubygems => "< 2.0" do
        it "requires a newer rubygems version" do
          instance_eval(&trigger)
          expect(warnings).to have_major_deprecation "Carat will only support rubygems >= 2.0, you are running #{Gem::VERSION}"
        end
      end
    end

    describe "-rcarat/setup" do
      it_behaves_like "environmental deprecations", proc { ruby "require 'carat/setup'" }
    end

    describe "Carat.setup" do
      it_behaves_like "environmental deprecations", proc { ruby "require 'carat'; Carat.setup" }
    end

    describe "carat check" do
      it_behaves_like "environmental deprecations", proc { carat :check }
    end

    describe "carat update --quiet" do
      it "does not print any deprecations" do
        carat :update, :quiet => true
        expect(warnings_without_version_messages).not_to have_major_deprecation
      end
    end

    describe "carat update" do
      before do
        create_file("gems.rb", "")
        carat! "install"
      end

      it "warns when no options are given" do
        carat! "update"
        expect(warnings).to have_major_deprecation a_string_including("Pass --all to `carat update` to update everything")
      end

      it "does not warn when --all is passed" do
        carat! "update --all"
        expect(warnings_without_version_messages).not_to have_major_deprecation
      end
    end

    describe "carat install --binstubs" do
      it "should output a deprecation warning" do
        gemfile <<-G
          gem 'rack'
        G

        carat :install, :binstubs => true
        expect(warnings).to have_major_deprecation a_string_including("The --binstubs option will be removed")
      end
    end
  end

  context "when carat is run" do
    it "should not warn about gems.rb" do
      create_file "gems.rb", <<-G
        source "file://#{gem_repo1}"
        gem "rack"
      G

      carat :install
      expect(warnings_without_version_messages).not_to have_major_deprecation
    end

    it "should print a Gemfile deprecation warning" do
      create_file "gems.rb"
      install_gemfile! <<-G
        source "file://#{gem_repo1}"
        gem "rack"
      G
      expect(the_carat).to include_gem "rack 1.0"

      expect(warnings).to have_major_deprecation a_string_including("gems.rb and gems.locked will be preferred to Gemfile and Gemfile.lock.")
    end

    context "with flags" do
      it "should print a deprecation warning about autoremembering flags" do
        install_gemfile <<-G, :path => "vendor/carat"
          source "file://#{gem_repo1}"
          gem "rack"
        G

        expect(warnings).to have_major_deprecation a_string_including(
          "flags passed to commands will no longer be automatically remembered."
        )
      end
    end
  end

  context "when Carat.setup is run in a ruby script" do
    it "should print a single deprecation warning" do
      create_file "gems.rb"
      install_gemfile! <<-G
        source "file://#{gem_repo1}"
        gem "rack", :group => :test
      G

      ruby <<-RUBY
        require 'rubygems'
        require 'carat'
        require 'carat/vendored_thor'

        Carat.ui = Carat::UI::Shell.new
        Carat.setup
        Carat.setup
      RUBY

      expect(warnings_without_version_messages).to have_major_deprecation("gems.rb and gems.locked will be preferred to Gemfile and Gemfile.lock.")
    end
  end

  context "when `carat/deployment` is required in a ruby script" do
    it "should print a capistrano deprecation warning" do
      ruby(<<-RUBY)
        require 'carat/deployment'
      RUBY

      expect(warnings).to have_major_deprecation("Carat no longer integrates " \
                             "with Capistrano, but Capistrano provides " \
                             "its own integration with Carat via the " \
                             "capistrano-carat gem. Use it instead.")
    end
  end

  describe Carat::Dsl do
    before do
      @rubygems = double("rubygems")
      allow(Carat::Source::Rubygems).to receive(:new) { @rubygems }
    end

    context "with github gems" do
      it "warns about the https change" do
        msg = <<-EOS
The :github git source is deprecated, and will be removed in Carat 2.0. Change any "reponame" :github sources to "username/reponame". Add this code to the top of your Gemfile to ensure it continues to work:

    git_source(:github) {|repo_name| "https://github.com/\#{repo_name}.git" }

        EOS
        expect(Carat::SharedHelpers).to receive(:major_deprecation).with(2, msg)
        subject.gem("sparks", :github => "indirect/sparks")
      end

      it "upgrades to https on request" do
        Carat.settings.temporary "github.https" => true
        msg = <<-EOS
The :github git source is deprecated, and will be removed in Carat 2.0. Change any "reponame" :github sources to "username/reponame". Add this code to the top of your Gemfile to ensure it continues to work:

    git_source(:github) {|repo_name| "https://github.com/\#{repo_name}.git" }

        EOS
        expect(Carat::SharedHelpers).to receive(:major_deprecation).with(2, msg)
        expect(Carat::SharedHelpers).to receive(:major_deprecation).with(2, "The `github.https` setting will be removed")
        subject.gem("sparks", :github => "indirect/sparks")
        github_uri = "https://github.com/indirect/sparks.git"
        expect(subject.dependencies.first.source.uri).to eq(github_uri)
      end
    end

    context "with bitbucket gems" do
      it "warns about removal" do
        allow(Carat.ui).to receive(:deprecate)
        msg = <<-EOS
The :bitbucket git source is deprecated, and will be removed in Carat 2.0. Add this code to the top of your Gemfile to ensure it continues to work:

    git_source(:bitbucket) do |repo_name|
      user_name, repo_name = repo_name.split("/")
      repo_name ||= user_name
      "https://\#{user_name}@bitbucket.org/\#{user_name}/\#{repo_name}.git"
    end

        EOS
        expect(Carat::SharedHelpers).to receive(:major_deprecation).with(2, msg)
        subject.gem("not-really-a-gem", :bitbucket => "mcorp/flatlab-rails")
      end
    end

    context "with gist gems" do
      it "warns about removal" do
        allow(Carat.ui).to receive(:deprecate)
        msg = "The :gist git source is deprecated, and will be removed " \
          "in Carat 2.0. Add this code to the top of your Gemfile to ensure it " \
          "continues to work:\n\n    git_source(:gist) {|repo_name| " \
          "\"https://gist.github.com/\#{repo_name}.git\" }\n\n"
        expect(Carat::SharedHelpers).to receive(:major_deprecation).with(2, msg)
        subject.gem("not-really-a-gem", :gist => "1234")
      end
    end
  end

  context "carat show" do
    it "prints a deprecation warning" do
      install_gemfile! <<-G
        source "file://#{gem_repo1}"
        gem "rack"
      G

      carat! :show

      warnings.gsub!(/gems included.*?\[DEPRECATED/im, "[DEPRECATED")

      expect(warnings).to have_major_deprecation a_string_including("use `carat list` instead of `carat show`")
    end
  end

  context "carat console" do
    it "prints a deprecation warning" do
      carat "console"

      expect(warnings).to have_major_deprecation \
        a_string_including("carat console will be replaced by `bin/console` generated by `carat gem <name>`")
    end
  end
end
