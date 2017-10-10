# frozen_string_literal: true

RSpec.describe Carat::Plugin::API do
  context "plugin declarations" do
    before do
      stub_const "UserPluginClass", Class.new(Carat::Plugin::API)
    end

    describe "#command" do
      it "declares a command plugin with same class as handler" do
        expect(Carat::Plugin).
          to receive(:add_command).with("meh", UserPluginClass).once

        UserPluginClass.command "meh"
      end

      it "accepts another class as argument that handles the command" do
        stub_const "NewClass", Class.new
        expect(Carat::Plugin).to receive(:add_command).with("meh", NewClass).once

        UserPluginClass.command "meh", NewClass
      end
    end

    describe "#source" do
      it "declares a source plugin with same class as handler" do
        expect(Carat::Plugin).
          to receive(:add_source).with("a_source", UserPluginClass).once

        UserPluginClass.source "a_source"
      end

      it "accepts another class as argument that handles the command" do
        stub_const "NewClass", Class.new
        expect(Carat::Plugin).to receive(:add_source).with("a_source", NewClass).once

        UserPluginClass.source "a_source", NewClass
      end
    end

    describe "#hook" do
      it "accepts a block and passes it to Plugin module" do
        foo = double("tester")
        expect(foo).to receive(:called)

        expect(Carat::Plugin).to receive(:add_hook).with("post-foo").and_yield

        Carat::Plugin::API.hook("post-foo") { foo.called }
      end
    end
  end

  context "carat interfaces provided" do
    before do
      stub_const "UserPluginClass", Class.new(Carat::Plugin::API)
    end

    subject(:api) { UserPluginClass.new }

    # A test of delegation
    it "provides the Carat's functions" do
      expect(Carat).to receive(:an_unknown_function).once

      api.an_unknown_function
    end

    it "includes Carat::SharedHelpers' functions" do
      expect(Carat::SharedHelpers).to receive(:an_unknown_helper).once

      api.an_unknown_helper
    end

    context "#tmp" do
      it "provides a tmp dir" do
        expect(api.tmp("mytmp")).to be_directory
      end

      it "accepts multiple names for suffix" do
        expect(api.tmp("myplugin", "download")).to be_directory
      end
    end
  end
end
