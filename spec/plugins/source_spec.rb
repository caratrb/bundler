# frozen_string_literal: true

RSpec.describe "carat source plugin" do
  describe "plugins dsl eval for #source with :type option" do
    before do
      update_repo2 do
        build_plugin "carat-source-psource" do |s|
          s.write "plugins.rb", <<-RUBY
              class OPSource < Carat::Plugin::API
                source "psource"
              end
          RUBY
        end
      end
    end

    it "installs carat-source-* gem when no handler for source is present" do
      install_gemfile <<-G
        source "file://#{gem_repo2}"
        source "file://#{lib_path("gitp")}", :type => :psource do
        end
      G

      plugin_should_be_installed("carat-source-psource")
    end

    it "enables the plugin to require a lib path" do
      update_repo2 do
        build_plugin "carat-source-psource" do |s|
          s.write "plugins.rb", <<-RUBY
            require "carat-source-psource"
            class PSource < Carat::Plugin::API
              source "psource"
            end
          RUBY
        end
      end

      install_gemfile <<-G
        source "file://#{gem_repo2}"
        source "file://#{lib_path("gitp")}", :type => :psource do
        end
      G

      expect(out).to include("Carat complete!")
    end

    context "with an explicit handler" do
      before do
        update_repo2 do
          build_plugin "another-psource" do |s|
            s.write "plugins.rb", <<-RUBY
                class Cheater < Carat::Plugin::API
                  source "psource"
                end
            RUBY
          end
        end
      end

      context "explicit presence in gemfile" do
        before do
          install_gemfile <<-G
            source "file://#{gem_repo2}"

            plugin "another-psource"

            source "file://#{lib_path("gitp")}", :type => :psource do
            end
          G
        end

        it "completes successfully" do
          expect(out).to include("Carat complete!")
        end

        it "installs the explicit one" do
          plugin_should_be_installed("another-psource")
        end

        it "doesn't install the default one" do
          plugin_should_not_be_installed("carat-source-psource")
        end
      end

      context "explicit default source" do
        before do
          install_gemfile <<-G
            source "file://#{gem_repo2}"

            plugin "carat-source-psource"

            source "file://#{lib_path("gitp")}", :type => :psource do
            end
          G
        end

        it "completes successfully" do
          expect(out).to include("Carat complete!")
        end

        it "installs the default one" do
          plugin_should_be_installed("carat-source-psource")
        end
      end
    end
  end
end
