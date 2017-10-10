# frozen_string_literal: true

RSpec.describe Carat::SharedHelpers do
  let(:ext_lock_double) { double(:ext_lock) }

  before do
    allow(Carat.rubygems).to receive(:ext_lock).and_return(ext_lock_double)
    allow(ext_lock_double).to receive(:synchronize) {|&block| block.call }
  end

  subject { Carat::SharedHelpers }

  describe "#default_gemfile" do
    before { ENV["CARAT_GEMFILE"] = "/path/Gemfile" }

    context "Gemfile is present" do
      let(:expected_gemfile_path) { Pathname.new("/path/Gemfile") }

      it "returns the Gemfile path" do
        expect(subject.default_gemfile).to eq(expected_gemfile_path)
      end
    end

    context "Gemfile is not present" do
      before { ENV["CARAT_GEMFILE"] = nil }

      it "raises a GemfileNotFound error" do
        expect { subject.default_gemfile }.to raise_error(
          Carat::GemfileNotFound, "Could not locate Gemfile"
        )
      end
    end

    context "Gemfile is not an absolute path" do
      before { ENV["CARAT_GEMFILE"] = "Gemfile" }

      let(:expected_gemfile_path) { Pathname.new("Gemfile").expand_path }

      it "returns the Gemfile path" do
        expect(subject.default_gemfile).to eq(expected_gemfile_path)
      end
    end
  end

  describe "#default_lockfile" do
    context "gemfile is gems.rb" do
      let(:gemfile_path)           { Pathname.new("/path/gems.rb") }
      let(:expected_lockfile_path) { Pathname.new("/path/gems.locked") }

      before { allow(subject).to receive(:default_gemfile).and_return(gemfile_path) }

      it "returns the gems.locked path" do
        expect(subject.default_lockfile).to eq(expected_lockfile_path)
      end
    end

    context "is a regular Gemfile" do
      let(:gemfile_path)           { Pathname.new("/path/Gemfile") }
      let(:expected_lockfile_path) { Pathname.new("/path/Gemfile.lock") }

      before { allow(subject).to receive(:default_gemfile).and_return(gemfile_path) }

      it "returns the lock file path" do
        expect(subject.default_lockfile).to eq(expected_lockfile_path)
      end
    end
  end

  describe "#default_carat_dir" do
    context ".carat does not exist" do
      it "returns nil" do
        expect(subject.default_carat_dir).to be_nil
      end
    end

    context ".carat is global .carat" do
      let(:global_rubygems_dir) { Pathname.new("#{carated_app}") }

      before do
        Dir.mkdir ".carat"
        allow(Carat.rubygems).to receive(:user_home).and_return(global_rubygems_dir)
      end

      it "returns nil" do
        expect(subject.default_carat_dir).to be_nil
      end
    end

    context ".carat is not global .carat" do
      let(:global_rubygems_dir)      { Pathname.new("/path/rubygems") }
      let(:expected_carat_dir_path) { Pathname.new("#{carated_app}/.carat") }

      before do
        Dir.mkdir ".carat"
        allow(Carat.rubygems).to receive(:user_home).and_return(global_rubygems_dir)
      end

      it "returns the .carat path" do
        expect(subject.default_carat_dir).to eq(expected_carat_dir_path)
      end
    end
  end

  describe "#in_carat?" do
    it "calls the find_gemfile method" do
      expect(subject).to receive(:find_gemfile)
      subject.in_carat?
    end

    shared_examples_for "correctly determines whether to return a Gemfile path" do
      context "currently in directory with a Gemfile" do
        before { File.new("Gemfile", "w") }

        it "returns path of the carat Gemfile" do
          expect(subject.in_carat?).to eq("#{carated_app}/Gemfile")
        end
      end

      context "currently in directory without a Gemfile" do
        it "returns nil" do
          expect(subject.in_carat?).to be_nil
        end
      end
    end

    context "ENV['CARAT_GEMFILE'] set" do
      before { ENV["CARAT_GEMFILE"] = "/path/Gemfile" }

      it "returns ENV['CARAT_GEMFILE']" do
        expect(subject.in_carat?).to eq("/path/Gemfile")
      end
    end

    context "ENV['CARAT_GEMFILE'] not set" do
      before { ENV["CARAT_GEMFILE"] = nil }

      it_behaves_like "correctly determines whether to return a Gemfile path"
    end

    context "ENV['CARAT_GEMFILE'] is blank" do
      before { ENV["CARAT_GEMFILE"] = "" }

      it_behaves_like "correctly determines whether to return a Gemfile path"
    end
  end

  describe "#chdir" do
    let(:op_block) { proc { Dir.mkdir "nested_dir" } }

    before { Dir.mkdir "chdir_test_dir" }

    it "executes the passed block while in the specified directory" do
      subject.chdir("chdir_test_dir", &op_block)
      expect(Pathname.new("chdir_test_dir/nested_dir")).to exist
    end
  end

  describe "#pwd" do
    it "returns the current absolute path" do
      expect(subject.pwd).to eq(carated_app)
    end
  end

  describe "#with_clean_git_env" do
    let(:with_clean_git_env_block) { proc { Dir.mkdir "with_clean_git_env_test_dir" } }

    before do
      ENV["GIT_DIR"] = "ORIGINAL_ENV_GIT_DIR"
      ENV["GIT_WORK_TREE"] = "ORIGINAL_ENV_GIT_WORK_TREE"
    end

    it "executes the passed block" do
      subject.with_clean_git_env(&with_clean_git_env_block)
      expect(Pathname.new("with_clean_git_env_test_dir")).to exist
    end

    context "when a block is passed" do
      let(:with_clean_git_env_block) do
        proc do
          Dir.mkdir "git_dir_test_dir" unless ENV["GIT_DIR"].nil?
          Dir.mkdir "git_work_tree_test_dir" unless ENV["GIT_WORK_TREE"].nil?
        end end

      it "uses a fresh git env for execution" do
        subject.with_clean_git_env(&with_clean_git_env_block)
        expect(Pathname.new("git_dir_test_dir")).to_not exist
        expect(Pathname.new("git_work_tree_test_dir")).to_not exist
      end
    end

    context "passed block does not throw errors" do
      let(:with_clean_git_env_block) do
        proc do
          ENV["GIT_DIR"] = "NEW_ENV_GIT_DIR"
          ENV["GIT_WORK_TREE"] = "NEW_ENV_GIT_WORK_TREE"
        end end

      it "restores the git env after" do
        subject.with_clean_git_env(&with_clean_git_env_block)
        expect(ENV["GIT_DIR"]).to eq("ORIGINAL_ENV_GIT_DIR")
        expect(ENV["GIT_WORK_TREE"]).to eq("ORIGINAL_ENV_GIT_WORK_TREE")
      end
    end

    context "passed block throws errors" do
      let(:with_clean_git_env_block) do
        proc do
          ENV["GIT_DIR"] = "NEW_ENV_GIT_DIR"
          ENV["GIT_WORK_TREE"] = "NEW_ENV_GIT_WORK_TREE"
          raise RuntimeError.new
        end end

      it "restores the git env after" do
        expect { subject.with_clean_git_env(&with_clean_git_env_block) }.to raise_error(RuntimeError)
        expect(ENV["GIT_DIR"]).to eq("ORIGINAL_ENV_GIT_DIR")
        expect(ENV["GIT_WORK_TREE"]).to eq("ORIGINAL_ENV_GIT_WORK_TREE")
      end
    end
  end

  describe "#set_carat_environment" do
    before do
      ENV["CARAT_GEMFILE"] = "Gemfile"
    end

    shared_examples_for "ENV['PATH'] gets set correctly" do
      before { Dir.mkdir ".carat" }

      it "ensures carat bin path is in ENV['PATH']" do
        subject.set_carat_environment
        paths = ENV["PATH"].split(File::PATH_SEPARATOR)
        expect(paths).to include("#{Carat.carat_path}/bin")
      end
    end

    shared_examples_for "ENV['RUBYOPT'] gets set correctly" do
      it "ensures -rcarat/setup is at the beginning of ENV['RUBYOPT']" do
        subject.set_carat_environment
        expect(ENV["RUBYOPT"].split(" ")).to start_with("-rcarat/setup")
      end
    end

    shared_examples_for "ENV['RUBYLIB'] gets set correctly" do
      let(:ruby_lib_path) { "stubbed_ruby_lib_dir" }

      before do
        allow(Carat::SharedHelpers).to receive(:carat_ruby_lib).and_return(ruby_lib_path)
      end

      it "ensures carat's ruby version lib path is in ENV['RUBYLIB']" do
        subject.set_carat_environment
        paths = (ENV["RUBYLIB"]).split(File::PATH_SEPARATOR)
        expect(paths).to include(ruby_lib_path)
      end
    end

    it "calls the appropriate set methods" do
      expect(subject).to receive(:set_path)
      expect(subject).to receive(:set_rubyopt)
      expect(subject).to receive(:set_rubylib)
      subject.set_carat_environment
    end

    it "exits if carat path contains the unix-like path separator" do
      if Gem.respond_to?(:path_separator)
        allow(Gem).to receive(:path_separator).and_return(":")
      else
        stub_const("File::PATH_SEPARATOR", ":".freeze)
      end
      allow(Carat).to receive(:carat_path) { Pathname.new("so:me/dir/bin") }
      expect { subject.send(:validate_carat_path) }.to raise_error(
        Carat::PathError,
        "Your carat path contains text matching \":\", which is the " \
        "path separator for your system. Carat cannot " \
        "function correctly when the Carat path contains the " \
        "system's PATH separator. Please change your " \
        "carat path to not match \":\".\nYour current carat " \
        "path is '#{Carat.carat_path}'."
      )
    end

    context "with a jruby path_separator regex", :ruby => "1.9" do
      # In versions of jruby that supported ruby 1.8, the path separator was the standard File::PATH_SEPARATOR
      let(:regex) { Regexp.new("(?<!jar:file|jar|file|classpath|uri:classloader|uri|http|https):") }
      it "does not exit if carat path is the standard uri path" do
        allow(Carat.rubygems).to receive(:path_separator).and_return(regex)
        allow(Carat).to receive(:carat_path) { Pathname.new("uri:classloader:/WEB-INF/gems") }
        expect { subject.send(:validate_carat_path) }.not_to raise_error
      end

      it "exits if carat path contains another directory" do
        allow(Carat.rubygems).to receive(:path_separator).and_return(regex)
        allow(Carat).to receive(:carat_path) {
          Pathname.new("uri:classloader:/WEB-INF/gems:other/dir")
        }

        expect { subject.send(:validate_carat_path) }.to raise_error(
          Carat::PathError,
          "Your carat path contains text matching " \
          "/(?<!jar:file|jar|file|classpath|uri:classloader|uri|http|https):/, which is the " \
          "path separator for your system. Carat cannot " \
          "function correctly when the Carat path contains the " \
          "system's PATH separator. Please change your " \
          "carat path to not match " \
          "/(?<!jar:file|jar|file|classpath|uri:classloader|uri|http|https):/." \
          "\nYour current carat path is '#{Carat.carat_path}'."
        )
      end
    end

    context "ENV['PATH'] does not exist" do
      before { ENV.delete("PATH") }

      it_behaves_like "ENV['PATH'] gets set correctly"
    end

    context "ENV['PATH'] is empty" do
      before { ENV["PATH"] = "" }

      it_behaves_like "ENV['PATH'] gets set correctly"
    end

    context "ENV['PATH'] exists" do
      before { ENV["PATH"] = "/some_path/bin" }

      it_behaves_like "ENV['PATH'] gets set correctly"
    end

    context "ENV['PATH'] already contains the carat bin path" do
      let(:carat_path) { "#{Carat.carat_path}/bin" }

      before do
        ENV["PATH"] = carat_path
      end

      it_behaves_like "ENV['PATH'] gets set correctly"

      it "ENV['PATH'] should only contain one instance of carat bin path" do
        subject.set_carat_environment
        paths = (ENV["PATH"]).split(File::PATH_SEPARATOR)
        expect(paths.count(carat_path)).to eq(1)
      end
    end

    context "ENV['RUBYOPT'] does not exist" do
      before { ENV.delete("RUBYOPT") }

      it_behaves_like "ENV['RUBYOPT'] gets set correctly"
    end

    context "ENV['RUBYOPT'] exists without -rcarat/setup" do
      before { ENV["RUBYOPT"] = "-I/some_app_path/lib" }

      it_behaves_like "ENV['RUBYOPT'] gets set correctly"
    end

    context "ENV['RUBYOPT'] exists and contains -rcarat/setup" do
      before { ENV["RUBYOPT"] = "-rcarat/setup" }

      it_behaves_like "ENV['RUBYOPT'] gets set correctly"
    end

    context "ENV['RUBYLIB'] does not exist" do
      before { ENV.delete("RUBYLIB") }

      it_behaves_like "ENV['RUBYLIB'] gets set correctly"
    end

    context "ENV['RUBYLIB'] is empty" do
      before { ENV["PATH"] = "" }

      it_behaves_like "ENV['RUBYLIB'] gets set correctly"
    end

    context "ENV['RUBYLIB'] exists" do
      before { ENV["PATH"] = "/some_path/bin" }

      it_behaves_like "ENV['RUBYLIB'] gets set correctly"
    end

    context "ENV['RUBYLIB'] already contains the carat's ruby version lib path" do
      let(:ruby_lib_path) { "stubbed_ruby_lib_dir" }

      before do
        ENV["RUBYLIB"] = ruby_lib_path
      end

      it_behaves_like "ENV['RUBYLIB'] gets set correctly"

      it "ENV['RUBYLIB'] should only contain one instance of carat's ruby version lib path" do
        subject.set_carat_environment
        paths = (ENV["RUBYLIB"]).split(File::PATH_SEPARATOR)
        expect(paths.count(ruby_lib_path)).to eq(1)
      end
    end
  end

  describe "#filesystem_access" do
    context "system has proper permission access" do
      let(:file_op_block) { proc {|path| FileUtils.mkdir_p(path) } }

      it "performs the operation in the passed block" do
        subject.filesystem_access("./test_dir", &file_op_block)
        expect(Pathname.new("test_dir")).to exist
      end
    end

    context "system throws Errno::EACESS" do
      let(:file_op_block) { proc {|_path| raise Errno::EACCES } }

      it "raises a PermissionError" do
        expect { subject.filesystem_access("/path", &file_op_block) }.to raise_error(
          Carat::PermissionError
        )
      end
    end

    context "system throws Errno::EAGAIN" do
      let(:file_op_block) { proc {|_path| raise Errno::EAGAIN } }

      it "raises a TemporaryResourceError" do
        expect { subject.filesystem_access("/path", &file_op_block) }.to raise_error(
          Carat::TemporaryResourceError
        )
      end
    end

    context "system throws Errno::EPROTO" do
      let(:file_op_block) { proc {|_path| raise Errno::EPROTO } }

      it "raises a VirtualProtocolError" do
        expect { subject.filesystem_access("/path", &file_op_block) }.to raise_error(
          Carat::VirtualProtocolError
        )
      end
    end

    context "system throws Errno::ENOTSUP", :ruby => "1.9" do
      let(:file_op_block) { proc {|_path| raise Errno::ENOTSUP } }

      it "raises a OperationNotSupportedError" do
        expect { subject.filesystem_access("/path", &file_op_block) }.to raise_error(
          Carat::OperationNotSupportedError
        )
      end
    end

    context "system throws Errno::ENOSPC" do
      let(:file_op_block) { proc {|_path| raise Errno::ENOSPC } }

      it "raises a NoSpaceOnDeviceError" do
        expect { subject.filesystem_access("/path", &file_op_block) }.to raise_error(
          Carat::NoSpaceOnDeviceError
        )
      end
    end

    context "system throws an unhandled SystemCallError" do
      let(:error) { SystemCallError.new("Shields down", 1337) }
      let(:file_op_block) { proc {|_path| raise error } }

      it "raises a GenericSystemCallError" do
        expect { subject.filesystem_access("/path", &file_op_block) }.to raise_error(
          Carat::GenericSystemCallError, /error accessing.+underlying.+Shields down/m
        )
      end
    end
  end

  describe "#const_get_safely" do
    module TargetNamespace
      VALID_CONSTANT = 1
    end

    context "when the namespace does have the requested constant" do
      it "returns the value of the requested constant" do
        expect(subject.const_get_safely(:VALID_CONSTANT, TargetNamespace)).to eq(1)
      end
    end

    context "when the requested constant is passed as a string" do
      it "returns the value of the requested constant" do
        expect(subject.const_get_safely("VALID_CONSTANT", TargetNamespace)).to eq(1)
      end
    end

    context "when the namespace does not have the requested constant" do
      it "returns nil" do
        expect(subject.const_get_safely("INVALID_CONSTANT", TargetNamespace)).to be_nil
      end
    end
  end
end
