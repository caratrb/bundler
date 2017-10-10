# frozen_string_literal: true

RSpec.describe "Carat.with_env helpers" do
  describe "Carat.original_env" do
    before do
      carat "config path vendor/carat"
      gemfile ""
      carat "install"
    end

    it "should return the PATH present before carat was activated" do
      code = "print Carat.original_env['PATH']"
      path = `getconf PATH`.strip + "#{File::PATH_SEPARATOR}/foo"
      with_path_as(path) do
        result = carat("exec '#{Gem.ruby}' -e #{code.dump}")
        expect(result).to eq(path)
      end
    end

    it "should return the GEM_PATH present before carat was activated" do
      code = "print Carat.original_env['GEM_PATH']"
      gem_path = ENV["GEM_PATH"] + ":/foo"
      with_gem_path_as(gem_path) do
        result = carat("exec '#{Gem.ruby}' -e #{code.inspect}")
        expect(result).to eq(gem_path)
      end
    end

    it "works with nested carat exec invocations" do
      create_file("exe.rb", <<-'RB')
        count = ARGV.first.to_i
        exit if count < 0
        STDERR.puts "#{count} #{ENV["PATH"].end_with?(":/foo")}"
        if count == 2
          ENV["PATH"] = "#{ENV["PATH"]}:/foo"
        end
        exec(Gem.ruby, __FILE__, (count - 1).to_s)
      RB
      path = `getconf PATH`.strip + File::PATH_SEPARATOR + File.dirname(Gem.ruby)
      with_path_as(path) do
        carat!("exec '#{Gem.ruby}' #{carated_app("exe.rb")} 2")
      end
      expect(err).to eq <<-EOS.strip
2 false
1 true
0 true
      EOS
    end

    it "removes variables that carat added" do
      system_gems :carat
      original = ruby!('puts ENV.to_a.map {|e| e.join("=") }.sort.join("\n")')
      code = 'puts Carat.original_env.to_a.map {|e| e.join("=") }.sort.join("\n")'
      carat!("exec '#{Gem.ruby}' -e #{code.inspect}", :system_carat => true)
      expect(out).to eq original
    end
  end

  describe "Carat.clean_env", :carat => "< 2" do
    before do
      carat "config path vendor/carat"
      gemfile ""
      carat "install"
    end

    it "should delete CARAT_PATH" do
      code = "print Carat.clean_env.has_key?('CARAT_PATH')"
      ENV["CARAT_PATH"] = "./foo"
      result = carat("exec '#{Gem.ruby}' -e #{code.inspect}")
      expect(result).to eq("false")
    end

    it "should remove '-rcarat/setup' from RUBYOPT" do
      code = "print Carat.clean_env['RUBYOPT']"
      ENV["RUBYOPT"] = "-W2 -rcarat/setup"
      result = carat("exec '#{Gem.ruby}' -e #{code.inspect}")
      expect(result).not_to include("-rcarat/setup")
    end

    it "should clean up RUBYLIB" do
      code = "print Carat.clean_env['RUBYLIB']"
      ENV["RUBYLIB"] = root.join("lib").to_s + File::PATH_SEPARATOR + "/foo"
      result = carat("exec '#{Gem.ruby}' -e #{code.inspect}")
      expect(result).to eq("/foo")
    end

    it "should restore the original MANPATH" do
      code = "print Carat.clean_env['MANPATH']"
      ENV["MANPATH"] = "/foo"
      ENV["CARATR_ORIG_MANPATH"] = "/foo-original"
      result = carat("exec '#{Gem.ruby}' -e #{code.inspect}")
      expect(result).to eq("/foo-original")
    end
  end

  describe "Carat.with_original_env" do
    it "should set ENV to original_env in the block" do
      expected = Carat.original_env
      actual = Carat.with_original_env { ENV.to_hash }
      expect(actual).to eq(expected)
    end

    it "should restore the environment after execution" do
      Carat.with_original_env do
        ENV["FOO"] = "hello"
      end

      expect(ENV).not_to have_key("FOO")
    end
  end

  describe "Carat.with_clean_env", :carat => "< 2" do
    it "should set ENV to clean_env in the block" do
      expected = Carat.clean_env
      actual = Carat.with_clean_env { ENV.to_hash }
      expect(actual).to eq(expected)
    end

    it "should restore the environment after execution" do
      Carat.with_clean_env do
        ENV["FOO"] = "hello"
      end

      expect(ENV).not_to have_key("FOO")
    end
  end

  describe "Carat.clean_system", :ruby => ">= 1.9", :carat => "< 2" do
    it "runs system inside with_clean_env" do
      Carat.clean_system(%(echo 'if [ "$CARAT_PATH" = "" ]; then exit 42; else exit 1; fi' | /bin/sh))
      expect($?.exitstatus).to eq(42)
    end
  end

  describe "Carat.clean_exec", :ruby => ">= 1.9", :carat => "< 2" do
    it "runs exec inside with_clean_env" do
      pid = Kernel.fork do
        Carat.clean_exec(%(echo 'if [ "$CARAT_PATH" = "" ]; then exit 42; else exit 1; fi' | /bin/sh))
      end
      Process.wait(pid)
      expect($?.exitstatus).to eq(42)
    end
  end
end
