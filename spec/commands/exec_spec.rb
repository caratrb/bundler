# frozen_string_literal: true

RSpec.describe "carat exec" do
  let(:system_gems_to_install) { %w[rack-1.0.0 rack-0.9.1] }
  before :each do
    system_gems(system_gems_to_install, :path => :carat_path)
  end

  it "activates the correct gem" do
    gemfile <<-G
      gem "rack", "0.9.1"
    G

    carat "exec rackup"
    expect(out).to eq("0.9.1")
  end

  it "works when the bins are in ~/.carat" do
    install_gemfile <<-G
      gem "rack"
    G

    carat "exec rackup"
    expect(out).to eq("1.0.0")
  end

  it "works when running from a random directory" do
    install_gemfile <<-G
      gem "rack"
    G

    carat "exec 'cd #{tmp("gems")} && rackup'"

    expect(out).to include("1.0.0")
  end

  it "works when exec'ing something else" do
    install_gemfile 'gem "rack"'
    carat "exec echo exec"
    expect(out).to eq("exec")
  end

  it "works when exec'ing to ruby" do
    install_gemfile 'gem "rack"'
    carat "exec ruby -e 'puts %{hi}'"
    expect(out).to eq("hi")
  end

  it "accepts --verbose" do
    install_gemfile 'gem "rack"'
    carat "exec --verbose echo foobar"
    expect(out).to eq("foobar")
  end

  it "passes --verbose to command if it is given after the command" do
    install_gemfile 'gem "rack"'
    carat "exec echo --verbose"
    expect(out).to eq("--verbose")
  end

  it "handles --keep-file-descriptors" do
    require "tempfile"

    command = Tempfile.new("io-test")
    command.sync = true
    command.write <<-G
      if ARGV[0]
        IO.for_fd(ARGV[0].to_i)
      else
        require 'tempfile'
        io = Tempfile.new("io-test-fd")
        args = %W[#{Gem.ruby} -I#{lib} #{bindir.join("carat")} exec --keep-file-descriptors #{Gem.ruby} #{command.path} \#{io.to_i}]
        args << { io.to_i => io } if RUBY_VERSION >= "2.0"
        exec(*args)
      end
    G

    install_gemfile ""
    sys_exec("#{Gem.ruby} #{command.path}")

    if Carat.current_ruby.ruby_2?
      expect(out).to eq("")
    else
      expect(out).to eq("Ruby version #{RUBY_VERSION} defaults to keeping non-standard file descriptors on Kernel#exec.")
    end

    expect(err).to lack_errors
  end

  it "accepts --keep-file-descriptors" do
    install_gemfile ""
    carat "exec --keep-file-descriptors echo foobar"

    expect(err).to lack_errors
  end

  it "can run a command named --verbose" do
    install_gemfile 'gem "rack"'
    File.open("--verbose", "w") do |f|
      f.puts "#!/bin/sh"
      f.puts "echo foobar"
    end
    File.chmod(0o744, "--verbose")
    with_path_as(".") do
      carat "exec -- --verbose"
    end
    expect(out).to eq("foobar")
  end

  it "handles different versions in different carats" do
    build_repo2 do
      build_gem "rack_two", "1.0.0" do |s|
        s.executables = "rackup"
      end
    end

    install_gemfile <<-G
      source "file://#{gem_repo1}"
      gem "rack", "0.9.1"
    G

    Dir.chdir carated_app2 do
      install_gemfile carated_app2("Gemfile"), <<-G
        source "file://#{gem_repo2}"
        gem "rack_two", "1.0.0"
      G
    end

    carat! "exec rackup"

    expect(out).to eq("0.9.1")

    Dir.chdir carated_app2 do
      carat! "exec rackup"
      expect(out).to eq("1.0.0")
    end
  end

  it "handles gems installed with --without" do
    install_gemfile <<-G, forgotten_command_line_options(:without => "middleware")
      source "file://#{gem_repo1}"
      gem "rack" # rack 0.9.1 and 1.0 exist

      group :middleware do
        gem "rack_middleware" # rack_middleware depends on rack 0.9.1
      end
    G

    carat "exec rackup"

    expect(out).to eq("0.9.1")
    expect(the_carat).not_to include_gems "rack_middleware 1.0"
  end

  it "does not duplicate already exec'ed RUBYOPT" do
    install_gemfile <<-G
      gem "rack"
    G

    rubyopt = ENV["RUBYOPT"]
    rubyopt = "-rcarat/setup #{rubyopt}"

    carat "exec 'echo $RUBYOPT'"
    expect(out).to have_rubyopts(rubyopt)

    carat "exec 'echo $RUBYOPT'", :env => { "RUBYOPT" => rubyopt }
    expect(out).to have_rubyopts(rubyopt)
  end

  it "does not duplicate already exec'ed RUBYLIB" do
    install_gemfile <<-G
      gem "rack"
    G

    rubylib = ENV["RUBYLIB"]
    rubylib = "#{rubylib}".split(File::PATH_SEPARATOR).unshift "#{carat_path}"
    rubylib = rubylib.uniq.join(File::PATH_SEPARATOR)

    carat "exec 'echo $RUBYLIB'"
    expect(out).to include(rubylib)

    carat "exec 'echo $RUBYLIB'", :env => { "RUBYLIB" => rubylib }
    expect(out).to include(rubylib)
  end

  it "errors nicely when the argument doesn't exist" do
    install_gemfile <<-G
      gem "rack"
    G

    carat "exec foobarbaz"
    expect(exitstatus).to eq(127) if exitstatus
    expect(out).to include("carat: command not found: foobarbaz")
    expect(out).to include("Install missing gem executables with `carat install`")
  end

  it "errors nicely when the argument is not executable" do
    install_gemfile <<-G
      gem "rack"
    G

    carat "exec touch foo"
    carat "exec ./foo"
    expect(exitstatus).to eq(126) if exitstatus
    expect(out).to include("carat: not executable: ./foo")
  end

  it "errors nicely when no arguments are passed" do
    install_gemfile <<-G
      gem "rack"
    G

    carat "exec"
    expect(exitstatus).to eq(128) if exitstatus
    expect(out).to include("carat: exec needs a command to run")
  end

  it "raises a helpful error when exec'ing to something outside of the carat", :rubygems => ">= 2.5.2" do
    carat! "config clean false" # want to keep the rackup binstub
    install_gemfile! <<-G
      source "file://#{gem_repo1}"
      gem "with_license"
    G
    [true, false].each do |l|
      carat! "config disable_exec_load #{l}"
      carat "exec rackup"
      expect(last_command.stderr).to include "can't find executable rackup for gem rack. rack is not currently included in the carat, perhaps you meant to add it to your Gemfile?"
    end
  end

  # Different error message on old RG versions (before activate_bin_path) because they
  # called `Kernel#gem` directly
  it "raises a helpful error when exec'ing to something outside of the carat", :rubygems => "< 2.5.2" do
    install_gemfile! <<-G
      source "file://#{gem_repo1}"
      gem "with_license"
    G
    [true, false].each do |l|
      carat! "config disable_exec_load #{l}"
      carat "exec rackup"
      expect(last_command.stderr).to include "rack is not part of the carat. Add it to your Gemfile."
    end
  end

  describe "with help flags" do
    each_prefix = proc do |string, &blk|
      1.upto(string.length) {|l| blk.call(string[0, l]) }
    end
    each_prefix.call("exec") do |exec|
      describe "when #{exec} is used" do
        before(:each) do
          install_gemfile <<-G
            gem "rack"
          G

          create_file("print_args", <<-'RUBY')
            #!/usr/bin/env ruby
            puts "args: #{ARGV.inspect}"
          RUBY
          carated_app("print_args").chmod(0o755)
        end

        it "shows executable's man page when --help is after the executable" do
          carat "#{exec} print_args --help"
          expect(out).to eq('args: ["--help"]')
        end

        it "shows executable's man page when --help is after the executable and an argument" do
          carat "#{exec} print_args foo --help"
          expect(out).to eq('args: ["foo", "--help"]')

          carat "#{exec} print_args foo bar --help"
          expect(out).to eq('args: ["foo", "bar", "--help"]')

          carat "#{exec} print_args foo --help bar"
          expect(out).to eq('args: ["foo", "--help", "bar"]')
        end

        it "shows executable's man page when the executable has a -" do
          FileUtils.mv(carated_app("print_args"), carated_app("docker-template"))
          carat "#{exec} docker-template build discourse --help"
          expect(out).to eq('args: ["build", "discourse", "--help"]')
        end

        it "shows executable's man page when --help is after another flag" do
          carat "#{exec} print_args --bar --help"
          expect(out).to eq('args: ["--bar", "--help"]')
        end

        it "uses executable's original behavior for -h" do
          carat "#{exec} print_args -h"
          expect(out).to eq('args: ["-h"]')
        end

        it "shows carat-exec's man page when --help is between exec and the executable" do
          with_fake_man do
            carat "#{exec} --help cat"
          end
          expect(out).to include(%(["#{root}/man/carat-exec.1"]))
        end

        it "shows carat-exec's man page when --help is before exec" do
          with_fake_man do
            carat "--help #{exec}"
          end
          expect(out).to include(%(["#{root}/man/carat-exec.1"]))
        end

        it "shows carat-exec's man page when -h is before exec" do
          with_fake_man do
            carat "-h #{exec}"
          end
          expect(out).to include(%(["#{root}/man/carat-exec.1"]))
        end

        it "shows carat-exec's man page when --help is after exec" do
          with_fake_man do
            carat "#{exec} --help"
          end
          expect(out).to include(%(["#{root}/man/carat-exec.1"]))
        end

        it "shows carat-exec's man page when -h is after exec" do
          with_fake_man do
            carat "#{exec} -h"
          end
          expect(out).to include(%(["#{root}/man/carat-exec.1"]))
        end
      end
    end
  end

  describe "with gem executables" do
    describe "run from a random directory" do
      before(:each) do
        install_gemfile <<-G
          gem "rack"
        G
      end

      it "works when unlocked" do
        carat "exec 'cd #{tmp("gems")} && rackup'"
        expect(out).to eq("1.0.0")
        expect(out).to include("1.0.0")
      end

      it "works when locked" do
        expect(the_carat).to be_locked
        carat "exec 'cd #{tmp("gems")} && rackup'"
        expect(out).to include("1.0.0")
      end
    end

    describe "from gems carated via :path" do
      before(:each) do
        build_lib "fizz", :path => home("fizz") do |s|
          s.executables = "fizz"
        end

        install_gemfile <<-G
          gem "fizz", :path => "#{File.expand_path(home("fizz"))}"
        G
      end

      it "works when unlocked" do
        carat "exec fizz"
        expect(out).to eq("1.0")
      end

      it "works when locked" do
        expect(the_carat).to be_locked

        carat "exec fizz"
        expect(out).to eq("1.0")
      end
    end

    describe "from gems carated via :git" do
      before(:each) do
        build_git "fizz_git" do |s|
          s.executables = "fizz_git"
        end

        install_gemfile <<-G
          gem "fizz_git", :git => "#{lib_path("fizz_git-1.0")}"
        G
      end

      it "works when unlocked" do
        carat "exec fizz_git"
        expect(out).to eq("1.0")
      end

      it "works when locked" do
        expect(the_carat).to be_locked
        carat "exec fizz_git"
        expect(out).to eq("1.0")
      end
    end

    describe "from gems carated via :git with no gemspec" do
      before(:each) do
        build_git "fizz_no_gemspec", :gemspec => false do |s|
          s.executables = "fizz_no_gemspec"
        end

        install_gemfile <<-G
          gem "fizz_no_gemspec", "1.0", :git => "#{lib_path("fizz_no_gemspec-1.0")}"
        G
      end

      it "works when unlocked" do
        carat "exec fizz_no_gemspec"
        expect(out).to eq("1.0")
      end

      it "works when locked" do
        expect(the_carat).to be_locked
        carat "exec fizz_no_gemspec"
        expect(out).to eq("1.0")
      end
    end
  end

  it "performs an automatic carat install" do
    gemfile <<-G
      source "file://#{gem_repo1}"
      gem "rack", "0.9.1"
      gem "foo"
    G

    carat "config auto_install 1"
    carat "exec rackup"
    expect(out).to include("Installing foo 1.0")
  end

  describe "with gems carated via :path with invalid gemspecs" do
    it "outputs the gemspec validation errors", :rubygems => ">= 1.7.2" do
      build_lib "foo"

      gemspec = lib_path("foo-1.0").join("foo.gemspec").to_s
      File.open(gemspec, "w") do |f|
        f.write <<-G
          Gem::Specification.new do |s|
            s.name    = 'foo'
            s.version = '1.0'
            s.summary = 'TODO: Add summary'
            s.authors = 'Me'
          end
        G
      end

      install_gemfile <<-G
        gem "foo", :path => "#{lib_path("foo-1.0")}"
      G

      carat "exec irb"

      expect(err).to match("The gemspec at #{lib_path("foo-1.0").join("foo.gemspec")} is not valid")
      expect(err).to match('"TODO" is not a summary')
    end
  end

  describe "with gems carated for deployment" do
    it "works when calling carat from another script" do
      gemfile <<-G
      module Monkey
        def bin_path(a,b,c)
          raise Gem::GemNotFoundException.new('Fail')
        end
      end
      Carat.rubygems.extend(Monkey)
      G
      carat "install --deployment"
      carat "exec ruby -e '`#{bindir.join("carat")} -v`; puts $?.success?'"
      expect(out).to match("true")
    end
  end

  context "`load`ing a ruby file instead of `exec`ing" do
    let(:path) { carated_app("ruby_executable") }
    let(:shebang) { "#!/usr/bin/env ruby" }
    let(:executable) { <<-RUBY.gsub(/^ */, "").strip }
      #{shebang}

      require "rack"
      puts "EXEC: \#{caller.grep(/load/).empty? ? 'exec' : 'load'}"
      puts "ARGS: \#{$0} \#{ARGV.join(' ')}"
      puts "RACK: \#{RACK}"
      process_title = `ps -o args -p \#{Process.pid}`.split("\n", 2).last.strip
      puts "PROCESS: \#{process_title}"
    RUBY

    before do
      path.open("w") {|f| f << executable }
      path.chmod(0o755)

      install_gemfile <<-G
        gem "rack"
      G
    end

    let(:exec) { "EXEC: load" }
    let(:args) { "ARGS: #{path} arg1 arg2" }
    let(:rack) { "RACK: 1.0.0" }
    let(:process) do
      title = "PROCESS: #{path}"
      title += " arg1 arg2" if RUBY_VERSION >= "2.1"
      title
    end
    let(:exit_code) { 0 }
    let(:expected) { [exec, args, rack, process].join("\n") }
    let(:expected_err) { "" }

    subject { carat "exec #{path} arg1 arg2" }

    shared_examples_for "it runs" do
      it "like a normally executed executable" do
        subject
        expect(exitstatus).to eq(exit_code) if exitstatus
        expect(last_command.stderr).to eq(expected_err)
        expect(last_command.stdout).to eq(expected)
      end
    end

    it_behaves_like "it runs"

    context "the executable exits explicitly" do
      let(:executable) { super() << "\nexit #{exit_code}\nputs 'POST_EXIT'\n" }

      context "with exit 0" do
        it_behaves_like "it runs"
      end

      context "with exit 99" do
        let(:exit_code) { 99 }
        it_behaves_like "it runs"
      end
    end

    context "the executable is empty", :carat => "< 2" do
      let(:executable) { "" }

      let(:exit_code) { 0 }
      let(:expected) { "#{path} is empty" }
      let(:expected_err) { "" }
      if LessThanProc.with(RUBY_VERSION).call("1.9")
        # Kernel#exec in ruby < 1.9 will raise Errno::ENOEXEC if the command content is empty,
        # even if the command is set as an executable.
        pending "Kernel#exec is different"
      else
        it_behaves_like "it runs"
      end
    end

    context "the executable is empty", :carat => "2" do
      let(:executable) { "" }

      let(:exit_code) { 0 }
      let(:expected_err) { "#{path} is empty" }
      let(:expected) { "" }
      it_behaves_like "it runs"
    end

    context "the executable raises", :carat => "< 2" do
      let(:executable) { super() << "\nraise 'ERROR'" }
      let(:exit_code) { 1 }
      let(:expected) { super() << "\ncarat: failed to load command: #{path} (#{path})" }
      let(:expected_err) do
        "RuntimeError: ERROR\n  #{path}:10" +
          (Carat.current_ruby.ruby_18? ? "" : ":in `<top (required)>'")
      end
      it_behaves_like "it runs"
    end

    context "the executable raises", :carat => "2" do
      let(:executable) { super() << "\nraise 'ERROR'" }
      let(:exit_code) { 1 }
      let(:expected_err) do
        "carat: failed to load command: #{path} (#{path})" \
        "\nRuntimeError: ERROR\n  #{path}:10:in `<top (required)>'"
      end
      it_behaves_like "it runs"
    end

    context "when the file uses the current ruby shebang" do
      let(:shebang) { "#!#{Gem.ruby}" }
      it_behaves_like "it runs"
    end

    context "when Carat.setup fails", :carat => "< 2" do
      before do
        gemfile <<-G
          gem 'rack', '2'
        G
        ENV["CARATR_FORCE_TTY"] = "true"
      end

      let(:exit_code) { Carat::GemNotFound.new.status_code }
      let(:expected) { <<-EOS.strip }
\e[31mCould not find gem 'rack (= 2)' in any of the gem sources listed in your Gemfile.\e[0m
\e[33mRun `carat install` to install missing gems.\e[0m
      EOS

      it_behaves_like "it runs"
    end

    context "when Carat.setup fails", :carat => "2" do
      before do
        gemfile <<-G
          gem 'rack', '2'
        G
        ENV["CARATR_FORCE_TTY"] = "true"
      end

      let(:exit_code) { Carat::GemNotFound.new.status_code }
      let(:expected) { <<-EOS.strip }
\e[31mCould not find gem 'rack (= 2)' in locally installed gems.
The source contains 'rack' at: 1.0.0\e[0m
\e[33mRun `carat install` to install missing gems.\e[0m
      EOS

      it_behaves_like "it runs"
    end

    context "when the executable exits non-zero via at_exit" do
      let(:executable) { super() + "\n\nat_exit { $! ? raise($!) : exit(1) }" }
      let(:exit_code) { 1 }

      it_behaves_like "it runs"
    end

    context "when disable_exec_load is set" do
      let(:exec) { "EXEC: exec" }
      let(:process) { "PROCESS: ruby #{path} arg1 arg2" }

      before do
        carat "config disable_exec_load true"
      end

      it_behaves_like "it runs"
    end

    context "regarding $0 and __FILE__" do
      let(:executable) { super() + <<-'RUBY' }

        puts "$0: #{$0.inspect}"
        puts "__FILE__: #{__FILE__.inspect}"
      RUBY

      let(:expected) { super() + <<-EOS.chomp }

$0: #{path.to_s.inspect}
__FILE__: #{path.to_s.inspect}
      EOS

      it_behaves_like "it runs"

      context "when the path is relative" do
        let(:path) { super().relative_path_from(carated_app) }

        if LessThanProc.with(RUBY_VERSION).call("1.9")
          pending "relative paths have ./ __FILE__"
        else
          it_behaves_like "it runs"
        end
      end

      context "when the path is relative with a leading ./" do
        let(:path) { Pathname.new("./#{super().relative_path_from(Pathname.pwd)}") }

        if LessThanProc.with(RUBY_VERSION).call("< 1.9")
          pending "relative paths with ./ have absolute __FILE__"
        else
          it_behaves_like "it runs"
        end
      end
    end

    context "signals being trapped by carat" do
      let(:executable) { strip_whitespace <<-RUBY }
        #{shebang}
        begin
          Thread.new do
            puts 'Started' # For process sync
            STDOUT.flush
            sleep 1 # ignore quality_spec
            raise "Didn't receive INT at all"
          end.join
        rescue Interrupt
          puts "foo"
        end
      RUBY

      it "receives the signal" do
        skip "popen3 doesn't provide a way to get pid " unless RUBY_VERSION >= "1.9.3"

        carat("exec #{path}") do |_, o, thr|
          o.gets # Consumes 'Started' and ensures that thread has started
          Process.kill("INT", thr.pid)
        end

        expect(out).to eq("foo")
      end
    end
  end

  context "nested carat exec" do
    let(:system_gems_to_install) { super() << :carat }

    context "with shared gems disabled" do
      before do
        gemfile <<-G
          source "file://#{gem_repo1}"
          gem "rack"
        G
        carat :install, :system_carat => true, :path => "vendor/carat"
      end

      it "overrides disable_shared_gems so carat can be found" do
        file = carated_app("file_that_carat_execs.rb")
        create_file(file, <<-RB)
          #!#{Gem.ruby}
          puts `carat exec echo foo`
        RB
        file.chmod(0o777)
        carat! "exec #{file}", :system_carat => true
        expect(out).to eq("foo")
      end
    end

    context "with a system gem that shadows a default gem" do
      let(:openssl_version) { "99.9.9" }
      let(:expected) { ruby "gem 'openssl', '< 999999'; require 'openssl'; puts OpenSSL::VERSION", :artifice => nil }

      it "only leaves the default gem in the stdlib available" do
        skip "openssl isn't a default gem" if expected.empty?

        install_gemfile! "" # must happen before installing the broken system gem

        build_repo4 do
          build_gem "openssl", openssl_version do |s|
            s.write("lib/openssl.rb", <<-RB)
              raise "custom openssl should not be loaded, it's not in the gemfile!"
            RB
          end
        end

        system_gems(:carat, "openssl-#{openssl_version}", :gem_repo => gem_repo4)

        file = carated_app("require_openssl.rb")
        create_file(file, <<-RB)
          #!/usr/bin/env ruby
          require "openssl"
          puts OpenSSL::VERSION
          warn Gem.loaded_specs.values.map(&:full_name)
        RB
        file.chmod(0o777)

        aggregate_failures do
          expect(carat!("exec #{file}", :system_carat => true, :artifice => nil)).to eq(expected)
          expect(carat!("exec carat exec #{file}", :system_carat => true, :artifice => nil)).to eq(expected)
          expect(carat!("exec ruby #{file}", :system_carat => true, :artifice => nil)).to eq(expected)
          expect(run!(file.read, :no_lib => true, :artifice => nil)).to eq(expected)
        end

        # sanity check that we get the newer, custom version without carat
        sys_exec("#{Gem.ruby} #{file}")
        expect(last_command.stderr).to include("custom openssl should not be loaded")
      end
    end
  end
end
