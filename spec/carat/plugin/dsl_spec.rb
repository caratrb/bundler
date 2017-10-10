# frozen_string_literal: true

RSpec.describe Carat::Plugin::DSL do
  DSL = Carat::Plugin::DSL

  subject(:dsl) { Carat::Plugin::DSL.new }

  before do
    allow(Carat).to receive(:root) { Pathname.new "/" }
  end

  describe "it ignores only the methods defined in Carat::Dsl" do
    it "doesn't raises error for Dsl methods" do
      expect { dsl.install_if }.not_to raise_error
    end

    it "raises error for other methods" do
      expect { dsl.no_method }.to raise_error(DSL::PluginGemfileError)
    end
  end

  describe "source block" do
    it "adds #source with :type to list and also inferred_plugins list" do
      expect(dsl).to receive(:plugin).with("carat-source-news").once

      dsl.source("some_random_url", :type => "news") {}

      expect(dsl.inferred_plugins).to eq(["carat-source-news"])
    end

    it "registers a source type plugin only once for multiple declataions" do
      expect(dsl).to receive(:plugin).with("carat-source-news").and_call_original.once

      dsl.source("some_random_url", :type => "news") {}
      dsl.source("another_random_url", :type => "news") {}
    end
  end
end
