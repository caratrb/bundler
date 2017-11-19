require "spec_helper"

describe "Carat.with_env helpers" do

  shared_examples_for "Carat.with_*_env" do
    it "should reset and restore the environment" do
      gem_path = ENV['GEM_PATH']

      Carat.with_clean_env do
        expect(`echo $GEM_PATH`.strip).not_to eq(gem_path)
      end

      expect(ENV['GEM_PATH']).to eq(gem_path)
    end
  end

  around do |example|
    env = Carat::ORIGINAL_ENV.dup
    Carat::ORIGINAL_ENV['BUNDLE_PATH'] = "./Gemfile"
    example.run
    Carat::ORIGINAL_ENV.replace env
  end

  describe "Carat.with_clean_env" do

    it_should_behave_like "Carat.with_*_env"

    it "should keep the original GEM_PATH even in sub processes" do
      gemfile ""
      carat "install --path vendor/bundle"

      code = "Carat.with_clean_env do;" +
             "  print ENV['GEM_PATH'] != '';" +
             "end"

      result = carat "exec ruby -e #{code.inspect}"
      expect(result).to eq("true")
    end

    it "should not pass any carat environment variables" do
      Carat.with_clean_env do
        expect(`echo $BUNDLE_PATH`.strip).not_to eq('./Gemfile')
      end
    end

    it "should not pass RUBYOPT changes" do
      lib_path = File.expand_path('../../../lib', __FILE__)
      Carat::ORIGINAL_ENV['RUBYOPT'] = " -I#{lib_path} -rcarat/setup"

      Carat.with_clean_env do
        expect(`echo $RUBYOPT`.strip).not_to include '-rcarat/setup'
        expect(`echo $RUBYOPT`.strip).not_to include "-I#{lib_path}"
      end

      expect(Carat::ORIGINAL_ENV['RUBYOPT']).to eq(" -I#{lib_path} -rcarat/setup")
    end

    it "should not change ORIGINAL_ENV" do
      expect(Carat::ORIGINAL_ENV['BUNDLE_PATH']).to eq('./Gemfile')
    end

  end

  describe "Carat.with_original_env" do

    it_should_behave_like "Carat.with_*_env"

    it "should pass carat environment variables set before Carat was run" do
      Carat.with_original_env do
        expect(`echo $BUNDLE_PATH`.strip).to eq('./Gemfile')
      end
    end
  end

  describe "Carat.clean_system" do
    it "runs system inside with_clean_env" do
      Carat.clean_system(%{echo 'if [ "$BUNDLE_PATH" = "" ]; then exit 42; else exit 1; fi' | /bin/sh})
      expect($?.exitstatus).to eq(42)
    end
  end

  describe "Carat.clean_exec" do
    it "runs exec inside with_clean_env" do
      pid = Kernel.fork do
        Carat.clean_exec(%{echo 'if [ "$BUNDLE_PATH" = "" ]; then exit 42; else exit 1; fi' | /bin/sh})
      end
      Process.wait(pid)
      expect($?.exitstatus).to eq(42)
    end
  end
end
