# frozen_string_literal: true

RSpec.describe "carat install" do
  context "with gem sources" do
    context "when gems include post install messages" do
      it "should display the post-install messages after installing" do
        gemfile <<-G
          source "file://#{gem_repo1}"
          gem 'rack'
          gem 'thin'
          gem 'rack-obama'
        G

        carat :install
        expect(out).to include("Post-install message from rack:")
        expect(out).to include("Rack's post install message")
        expect(out).to include("Post-install message from thin:")
        expect(out).to include("Thin's post install message")
        expect(out).to include("Post-install message from rack-obama:")
        expect(out).to include("Rack-obama's post install message")
      end
    end

    context "when gems do not include post install messages" do
      it "should not display any post-install messages" do
        gemfile <<-G
          source "file://#{gem_repo1}"
          gem "activesupport"
        G

        carat :install
        expect(out).not_to include("Post-install message")
      end
    end

    context "when a dependecy includes a post install message" do
      it "should display the post install message" do
        gemfile <<-G
          source "file://#{gem_repo1}"
          gem 'rack_middleware'
        G

        carat :install
        expect(out).to include("Post-install message from rack:")
        expect(out).to include("Rack's post install message")
      end
    end
  end

  context "with git sources" do
    context "when gems include post install messages" do
      it "should display the post-install messages after installing" do
        build_git "foo" do |s|
          s.post_install_message = "Foo's post install message"
        end
        gemfile <<-G
          source "file://#{gem_repo1}"
          gem 'foo', :git => '#{lib_path("foo-1.0")}'
        G

        carat :install
        expect(out).to include("Post-install message from foo:")
        expect(out).to include("Foo's post install message")
      end

      it "should display the post-install messages if repo is updated" do
        build_git "foo" do |s|
          s.post_install_message = "Foo's post install message"
        end
        gemfile <<-G
          source "file://#{gem_repo1}"
          gem 'foo', :git => '#{lib_path("foo-1.0")}'
        G
        carat :install

        build_git "foo", "1.1" do |s|
          s.post_install_message = "Foo's 1.1 post install message"
        end
        gemfile <<-G
          source "file://#{gem_repo1}"
          gem 'foo', :git => '#{lib_path("foo-1.1")}'
        G
        carat :install

        expect(out).to include("Post-install message from foo:")
        expect(out).to include("Foo's 1.1 post install message")
      end

      it "should not display the post-install messages if repo is not updated" do
        build_git "foo" do |s|
          s.post_install_message = "Foo's post install message"
        end
        gemfile <<-G
          source "file://#{gem_repo1}"
          gem 'foo', :git => '#{lib_path("foo-1.0")}'
        G

        carat :install
        expect(out).to include("Post-install message from foo:")
        expect(out).to include("Foo's post install message")

        carat :install
        expect(out).not_to include("Post-install message")
      end
    end

    context "when gems do not include post install messages" do
      it "should not display any post-install messages" do
        build_git "foo" do |s|
          s.post_install_message = nil
        end
        gemfile <<-G
          source "file://#{gem_repo1}"
          gem 'foo', :git => '#{lib_path("foo-1.0")}'
        G

        carat :install
        expect(out).not_to include("Post-install message")
      end
    end
  end

  context "when ignore post-install messages for gem is set" do
    it "doesn't display any post-install messages" do
      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"
      G

      carat "config ignore_messages.rack true"

      carat :install
      expect(out).not_to include("Post-install message")
    end
  end

  context "when ignore post-install messages for all gems" do
    it "doesn't display any post-install messages" do
      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"
      G

      carat "config ignore_messages true"

      carat :install
      expect(out).not_to include("Post-install message")
    end
  end
end
