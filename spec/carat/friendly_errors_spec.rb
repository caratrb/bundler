# frozen_string_literal: true

require "carat"
require "carat/friendly_errors"
require "cgi"

RSpec.describe Carat, "friendly errors" do
  context "with invalid YAML in .gemrc" do
    before do
      File.open(Gem.configuration.config_file_name, "w") do |f|
        f.write "invalid: yaml: hah"
      end
    end

    after do
      FileUtils.rm(Gem.configuration.config_file_name)
    end

    it "reports a relevant friendly error message", :ruby => ">= 1.9", :rubygems => "< 2.5.0" do
      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"
      G

      carat :install, :env => { "DEBUG" => true }

      expect(out).to include("Your RubyGems configuration")
      expect(out).to include("invalid YAML syntax")
      expect(out).to include("Psych::SyntaxError")
      expect(out).not_to include("ERROR REPORT TEMPLATE")
      expect(exitstatus).to eq(25) if exitstatus
    end

    it "reports a relevant friendly error message", :ruby => ">= 1.9", :rubygems => ">= 2.5.0" do
      gemfile <<-G
        source "file://#{gem_repo1}"
        gem "rack"
      G

      carat :install, :env => { "DEBUG" => true }

      expect(last_command.stderr).to include("Failed to load #{home(".gemrc")}")
      expect(exitstatus).to eq(0) if exitstatus
    end
  end

  it "calls log_error in case of exception" do
    exception = Exception.new
    expect(Carat::FriendlyErrors).to receive(:exit_status).with(exception).and_return(1)
    expect do
      Carat.with_friendly_errors do
        raise exception
      end
    end.to raise_error(SystemExit)
  end

  it "calls exit_status on exception" do
    exception = Exception.new
    expect(Carat::FriendlyErrors).to receive(:log_error).with(exception)
    expect do
      Carat.with_friendly_errors do
        raise exception
      end
    end.to raise_error(SystemExit)
  end

  describe "#log_error" do
    shared_examples "Carat.ui receive error" do |error, message|
      it "" do
        expect(Carat.ui).to receive(:error).with(message || error.message)
        Carat::FriendlyErrors.log_error(error)
      end
    end

    shared_examples "Carat.ui receive trace" do |error|
      it "" do
        expect(Carat.ui).to receive(:trace).with(error)
        Carat::FriendlyErrors.log_error(error)
      end
    end

    context "YamlSyntaxError" do
      it_behaves_like "Carat.ui receive error", Carat::YamlSyntaxError.new(StandardError.new, "sample_message")

      it "Carat.ui receive trace" do
        std_error = StandardError.new
        exception = Carat::YamlSyntaxError.new(std_error, "sample_message")
        expect(Carat.ui).to receive(:trace).with(std_error)
        Carat::FriendlyErrors.log_error(exception)
      end
    end

    context "Dsl::DSLError, GemspecError" do
      it_behaves_like "Carat.ui receive error", Carat::Dsl::DSLError.new("description", "dsl_path", "backtrace")
      it_behaves_like "Carat.ui receive error", Carat::GemspecError.new
    end

    context "GemRequireError" do
      let(:orig_error) { StandardError.new }
      let(:error) { Carat::GemRequireError.new(orig_error, "sample_message") }

      before do
        allow(orig_error).to receive(:backtrace).and_return([])
      end

      it "Carat.ui receive error" do
        expect(Carat.ui).to receive(:error).with(error.message)
        Carat::FriendlyErrors.log_error(error)
      end

      it "writes to Carat.ui.trace" do
        expect(Carat.ui).to receive(:trace).with(orig_error, nil, true)
        Carat::FriendlyErrors.log_error(error)
      end
    end

    context "CaratError" do
      it "Carat.ui receive error" do
        error = Carat::CaratError.new
        expect(Carat.ui).to receive(:error).with(error.message, :wrap => true)
        Carat::FriendlyErrors.log_error(error)
      end
      it_behaves_like "Carat.ui receive trace", Carat::CaratError.new
    end

    context "Thor::Error" do
      it_behaves_like "Carat.ui receive error", Carat::Thor::Error.new
    end

    context "LoadError" do
      let(:error) { LoadError.new("cannot load such file -- openssl") }

      it "Carat.ui receive error" do
        expect(Carat.ui).to receive(:error).with("\nCould not load OpenSSL.")
        Carat::FriendlyErrors.log_error(error)
      end

      it "Carat.ui receive warn" do
        expect(Carat.ui).to receive(:warn).with(any_args, :wrap => true)
        Carat::FriendlyErrors.log_error(error)
      end

      it "Carat.ui receive trace" do
        expect(Carat.ui).to receive(:trace).with(error)
        Carat::FriendlyErrors.log_error(error)
      end
    end

    context "Interrupt" do
      it "Carat.ui receive error" do
        expect(Carat.ui).to receive(:error).with("\nQuitting...")
        Carat::FriendlyErrors.log_error(Interrupt.new)
      end
      it_behaves_like "Carat.ui receive trace", Interrupt.new
    end

    context "Gem::InvalidSpecificationException" do
      it "Carat.ui receive error" do
        error = Gem::InvalidSpecificationException.new
        expect(Carat.ui).to receive(:error).with(error.message, :wrap => true)
        Carat::FriendlyErrors.log_error(error)
      end
    end

    context "SystemExit" do
      # Does nothing
    end

    context "Java::JavaLang::OutOfMemoryError" do
      module Java
        module JavaLang
          class OutOfMemoryError < StandardError; end
        end
      end

      it "Carat.ui receive error" do
        error = Java::JavaLang::OutOfMemoryError.new
        expect(Carat.ui).to receive(:error).with(/JVM has run out of memory/)
        Carat::FriendlyErrors.log_error(error)
      end
    end

    context "unexpected error" do
      it "calls request_issue_report_for with error" do
        error = StandardError.new
        expect(Carat::FriendlyErrors).to receive(:request_issue_report_for).with(error)
        Carat::FriendlyErrors.log_error(error)
      end
    end
  end

  describe "#exit_status" do
    it "calls status_code for CaratError" do
      error = Carat::CaratError.new
      expect(error).to receive(:status_code).and_return("sample_status_code")
      expect(Carat::FriendlyErrors.exit_status(error)).to eq("sample_status_code")
    end

    it "returns 15 for Thor::Error" do
      error = Carat::Thor::Error.new
      expect(Carat::FriendlyErrors.exit_status(error)).to eq(15)
    end

    it "calls status for SystemExit" do
      error = SystemExit.new
      expect(error).to receive(:status).and_return("sample_status")
      expect(Carat::FriendlyErrors.exit_status(error)).to eq("sample_status")
    end

    it "returns 1 in other cases" do
      error = StandardError.new
      expect(Carat::FriendlyErrors.exit_status(error)).to eq(1)
    end
  end

  describe "#request_issue_report_for" do
    it "calls relevant methods for Carat.ui" do
      expect(Carat.ui).to receive(:info)
      expect(Carat.ui).to receive(:error)
      expect(Carat.ui).to receive(:warn)
      Carat::FriendlyErrors.request_issue_report_for(StandardError.new)
    end

    it "includes error class, message and backlog" do
      error = StandardError.new
      allow(Carat::FriendlyErrors).to receive(:issues_url).and_return("")

      expect(error).to receive(:class).at_least(:once)
      expect(error).to receive(:message).at_least(:once)
      expect(error).to receive(:backtrace).at_least(:once)
      Carat::FriendlyErrors.request_issue_report_for(error)
    end
  end

  describe "#issues_url" do
    it "generates a search URL for the exception message" do
      exception = Exception.new("Exception message")

      expect(Carat::FriendlyErrors.issues_url(exception)).to eq("https://github.com/caratrb/carat/search?q=Exception+message&type=Issues")
    end

    it "generates a search URL for only the first line of a multi-line exception message" do
      exception = Exception.new(<<END)
First line of the exception message
Second line of the exception message
END

      expect(Carat::FriendlyErrors.issues_url(exception)).to eq("https://github.com/caratrb/carat/search?q=First+line+of+the+exception+message&type=Issues")
    end

    it "generates the url without colons" do
      exception = Exception.new(<<END)
Exception ::: with ::: colons :::
END
      issues_url = Carat::FriendlyErrors.issues_url(exception)
      expect(issues_url).not_to include("%3A")
      expect(issues_url).to eq("https://github.com/caratrb/carat/search?q=#{CGI.escape("Exception     with     colons    ")}&type=Issues")
    end

    it "removes information after - for Errono::EACCES" do
      exception = Exception.new(<<END)
Errno::EACCES: Permission denied @ dir_s_mkdir - /Users/foo/bar/
END
      allow(exception).to receive(:is_a?).with(Errno).and_return(true)
      issues_url = Carat::FriendlyErrors.issues_url(exception)
      expect(issues_url).not_to include("/Users/foo/bar")
      expect(issues_url).to eq("https://github.com/caratrb/carat/search?q=#{CGI.escape("Errno  EACCES  Permission denied @ dir_s_mkdir ")}&type=Issues")
    end
  end
end
