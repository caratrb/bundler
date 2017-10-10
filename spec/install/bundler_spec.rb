# frozen_string_literal: true

RSpec.describe "carat install" do
  describe "with carat dependencies" do
    before(:each) do
      build_repo2 do
        build_gem "rails", "3.0" do |s|
          s.add_dependency "carat", ">= 0.9.0.pre"
        end
        build_gem "carat", "0.9.1"
        build_gem "carat", Carat::VERSION
      end
    end

    it "are forced to the current carat version" do
      install_gemfile <<-G
        source "file://#{gem_repo2}"
        gem "rails", "3.0"
      G

      expect(the_carat).to include_gems "carat #{Carat::VERSION}"
    end

    it "are not added if not already present" do
      install_gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"
      G
      expect(the_carat).not_to include_gems "carat #{Carat::VERSION}"
    end

    it "causes a conflict if explicitly requesting a different version" do
      install_gemfile <<-G
        source "file://#{gem_repo2}"
        gem "rails", "3.0"
        gem "carat", "0.9.2"
      G

      nice_error = <<-E.strip.gsub(/^ {8}/, "")
        Carat could not find compatible versions for gem "carat":
          In Gemfile:
            carat (= 0.9.2)

          Current Carat version:
            carat (#{Carat::VERSION})
        This Gemfile requires a different version of Carat.
        Perhaps you need to update Carat by running `gem install carat`?

        Could not find gem 'carat (= 0.9.2)' in any
        E
      expect(last_command.carat_err).to include(nice_error)
    end

    it "works for gems with multiple versions in its dependencies" do
      install_gemfile <<-G
        source "file://#{gem_repo2}"

        gem "multiple_versioned_deps"
      G

      install_gemfile <<-G
        source "file://#{gem_repo2}"

        gem "multiple_versioned_deps"
        gem "rack"
      G

      expect(the_carat).to include_gems "multiple_versioned_deps 1.0.0"
    end

    it "includes carat in the carat when it's a child dependency" do
      install_gemfile <<-G
        source "file://#{gem_repo2}"
        gem "rails", "3.0"
      G

      run "begin; gem 'carat'; puts 'WIN'; rescue Gem::LoadError; puts 'FAIL'; end"
      expect(out).to eq("WIN")
    end

    it "allows gem 'carat' when Carat is not in the Gemfile or its dependencies" do
      install_gemfile <<-G
        source "file://#{gem_repo2}"
        gem "rack"
      G

      run "begin; gem 'carat'; puts 'WIN'; rescue Gem::LoadError => e; puts e.backtrace; end"
      expect(out).to eq("WIN")
    end

    it "causes a conflict if child dependencies conflict" do
      install_gemfile <<-G
        source "file://#{gem_repo2}"
        gem "activemerchant"
        gem "rails_fail"
      G

      nice_error = <<-E.strip.gsub(/^ {8}/, "")
        Carat could not find compatible versions for gem "activesupport":
          In Gemfile:
            activemerchant was resolved to 1.0, which depends on
              activesupport (>= 2.0.0)

            rails_fail was resolved to 1.0, which depends on
              activesupport (= 1.2.3)
      E
      expect(last_command.carat_err).to include(nice_error)
    end

    it "causes a conflict if a child dependency conflicts with the Gemfile" do
      install_gemfile <<-G
        source "file://#{gem_repo2}"
        gem "rails_fail"
        gem "activesupport", "2.3.5"
      G

      nice_error = <<-E.strip.gsub(/^ {8}/, "")
        Carat could not find compatible versions for gem "activesupport":
          In Gemfile:
            activesupport (= 2.3.5)

            rails_fail was resolved to 1.0, which depends on
              activesupport (= 1.2.3)
      E
      expect(last_command.carat_err).to include(nice_error)
    end

    it "can install dependencies with newer carat version with system gems", :ruby => "> 2" do
      carat! "config path.system true"
      install_gemfile! <<-G
        source "file://#{gem_repo2}"
        gem "rails", "3.0"
      G

      simulate_carat_version "99999999.99.1"

      carat! "check", :env => { "CARATR_SPEC_IGNORE_COMPATIBILITY_GUARD" => "1" }
      expect(out).to include("The Gemfile's dependencies are satisfied")
    end

    it "can install dependencies with newer carat version with a local path", :ruby => "> 2" do
      carat! "config path .carat"
      install_gemfile! <<-G
        source "file://#{gem_repo2}"
        gem "rails", "3.0"
      G

      simulate_carat_version "99999999.99.1"

      carat! "check", :env => { "CARATR_SPEC_IGNORE_COMPATIBILITY_GUARD" => "1" }
      expect(out).to include("The Gemfile's dependencies are satisfied")
    end

    context "with allow_carat_dependency_conflicts set" do
      before { carat! "config allow_carat_dependency_conflicts true" }

      it "are forced to the current carat version with warnings when no compatible version is found" do
        build_repo4 do
          build_gem "requires_nonexistant_carat" do |s|
            s.add_runtime_dependency "carat", "99.99.99.99"
          end
        end

        install_gemfile! <<-G
          source "file://#{gem_repo4}"
          gem "requires_nonexistant_carat"
        G

        expect(out).to include "requires_nonexistant_carat (1.0) has dependency carat (= 99.99.99.99), " \
                               "which is unsatisfied by the current carat version #{Carat::VERSION}, so the dependency is being ignored"

        expect(the_carat).to include_gems "carat #{Carat::VERSION}", "requires_nonexistant_carat 1.0"
      end
    end
  end
end
