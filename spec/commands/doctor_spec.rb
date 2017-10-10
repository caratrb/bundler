# frozen_string_literal: true

require "stringio"
require "carat/cli"
require "carat/cli/doctor"

RSpec.describe "carat doctor" do
  before(:each) do
    @stdout = StringIO.new

    [:error, :warn].each do |method|
      allow(Carat.ui).to receive(method).and_wrap_original do |m, message|
        m.call message
        @stdout.puts message
      end
    end
  end

  it "exits with no message if the installed gem has no C extensions" do
    install_gemfile! <<-G
      source "file://#{gem_repo1}"
      gem "rack"
    G

    expect { Carat::CLI::Doctor.new({}).run }.not_to raise_error
    expect(@stdout.string).to be_empty
  end

  it "exits with no message if the installed gem's C extension dylib breakage is fine" do
    install_gemfile! <<-G
      source "file://#{gem_repo1}"
      gem "rack"
    G

    doctor = Carat::CLI::Doctor.new({})
    expect(doctor).to receive(:carats_for_gem).exactly(2).times.and_return ["/path/to/rack/rack.carat"]
    expect(doctor).to receive(:dylibs).exactly(2).times.and_return ["/usr/lib/libSystem.dylib"]
    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:exist?).with("/usr/lib/libSystem.dylib").and_return(true)
    expect { doctor.run }.not_to(raise_error, @stdout.string)
    expect(@stdout.string).to be_empty
  end

  it "exits with a message if one of the linked libraries is missing" do
    install_gemfile! <<-G
      source "file://#{gem_repo1}"
      gem "rack"
    G

    doctor = Carat::CLI::Doctor.new({})
    expect(doctor).to receive(:carats_for_gem).exactly(2).times.and_return ["/path/to/rack/rack.carat"]
    expect(doctor).to receive(:dylibs).exactly(2).times.and_return ["/usr/local/opt/icu4c/lib/libicui18n.57.1.dylib"]
    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:exist?).with("/usr/local/opt/icu4c/lib/libicui18n.57.1.dylib").and_return(false)
    expect { doctor.run }.to raise_error(Carat::ProductionError, strip_whitespace(<<-E).strip), @stdout.string
      The following gems are missing OS dependencies:
       * carat: /usr/local/opt/icu4c/lib/libicui18n.57.1.dylib
       * rack: /usr/local/opt/icu4c/lib/libicui18n.57.1.dylib
    E
  end
end
