require 'spec_helper'
require 'carat/definition'

describe Carat::Definition do
  before do
    allow(Carat).to receive(:settings){ Carat::Settings.new(".") }
    allow(Carat).to receive(:default_gemfile){ Pathname.new("Gemfile") }
  end

  describe "#lock" do
    context "when it's not possible to write to the file" do
      subject{ Carat::Definition.new(nil, [], Carat::SourceList.new, []) }

      it "raises an InstallError with explanation" do
        expect(File).to receive(:open).with("Gemfile.lock", "wb").
          and_raise(Errno::EACCES)
        expect{ subject.lock("Gemfile.lock") }.
          to raise_error(Carat::InstallError)
      end
    end
  end
end
