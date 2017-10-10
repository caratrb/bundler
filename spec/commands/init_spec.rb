# frozen_string_literal: true

RSpec.describe "carat init" do
  it "generates a Gemfile", :carat => "< 2" do
    carat! :init
    expect(out).to include("Writing new Gemfile")
    expect(carated_app("Gemfile")).to be_file
  end

  it "generates a gems.rb", :carat => "2" do
    carat! :init
    expect(out).to include("Writing new gems.rb")
    expect(carated_app("gems.rb")).to be_file
  end

  context "when a Gemfile already exists" do
    before do
      gemfile <<-G
        gem "rails"
      G
    end

    it "does not change existing Gemfiles" do
      expect { carat :init }.not_to change { File.read(carated_app("Gemfile")) }
    end

    it "notifies the user that an existing Gemfile already exists" do
      carat :init
      expect(out).to include("Gemfile already exists")
    end
  end

  context "when a gems.rb already exists" do
    before do
      create_file "gems.rb", <<-G
        gem "rails"
      G
    end

    it "does not change existing gem.rb files" do
      expect { carat :init }.not_to change { File.read(carated_app("gems.rb")) }
    end

    it "notifies the user that an existing gems.rb already exists" do
      carat :init
      expect(out).to include("gems.rb already exists")
    end
  end

  context "given --gemspec option", :carat => "< 2" do
    let(:spec_file) { tmp.join("test.gemspec") }

    it "should generate from an existing gemspec" do
      File.open(spec_file, "w") do |file|
        file << <<-S
          Gem::Specification.new do |s|
          s.name = 'test'
          s.add_dependency 'rack', '= 1.0.1'
          s.add_development_dependency 'rspec', '1.2'
          end
        S
      end

      carat :init, :gemspec => spec_file

      gemfile = if Carat::VERSION[0, 2] == "1."
        carated_app("Gemfile").read
      else
        carated_app("gems.rb").read
      end
      expect(gemfile).to match(%r{source 'https://rubygems.org'})
      expect(gemfile.scan(/gem "rack", "= 1.0.1"/).size).to eq(1)
      expect(gemfile.scan(/gem "rspec", "= 1.2"/).size).to eq(1)
      expect(gemfile.scan(/group :development/).size).to eq(1)
    end

    context "when gemspec file is invalid" do
      it "notifies the user that specification is invalid" do
        File.open(spec_file, "w") do |file|
          file << <<-S
            Gem::Specification.new do |s|
            s.name = 'test'
            s.invalid_method_name
            end
          S
        end

        carat :init, :gemspec => spec_file
        expect(last_command.carat_err).to include("There was an error while loading `test.gemspec`")
      end
    end
  end

  context "when init_gems_rb setting is enabled" do
    before { carat "config init_gems_rb true" }

    it "generates a gems.rb file" do
      carat :init
      expect(carated_app("gems.rb")).to exist
    end

    context "when gems.rb already exists" do
      before do
        create_file("gems.rb", <<-G)
          gem "rails"
        G
      end

      it "does not change existing Gemfiles" do
        expect { carat :init }.not_to change { File.read(carated_app("gems.rb")) }
      end

      it "notifies the user that an existing gems.rb already exists" do
        carat :init
        expect(out).to include("gems.rb already exists")
      end
    end

    context "given --gemspec option", :carat => "< 2" do
      let(:spec_file) { tmp.join("test.gemspec") }

      before do
        File.open(spec_file, "w") do |file|
          file << <<-S
            Gem::Specification.new do |s|
            s.name = 'test'
            s.add_dependency 'rack', '= 1.0.1'
            s.add_development_dependency 'rspec', '1.2'
            end
          S
        end
      end

      it "should generate from an existing gemspec" do
        carat :init, :gemspec => spec_file

        gemfile = carated_app("gems.rb").read
        expect(gemfile).to match(%r{source 'https://rubygems.org'})
        expect(gemfile.scan(/gem "rack", "= 1.0.1"/).size).to eq(1)
        expect(gemfile.scan(/gem "rspec", "= 1.2"/).size).to eq(1)
        expect(gemfile.scan(/group :development/).size).to eq(1)
      end

      it "prints message to user" do
        carat :init, :gemspec => spec_file

        expect(out).to include("Writing new gems.rb")
      end
    end
  end
end
