# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe MCPRails::Config do
  let(:default_config_path) { File.join(File.dirname(__FILE__), "..", "..", "mcp_rails.yml") }

  describe ".find_config_path" do
    it "returns default config path when no overrides exist" do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(File.join(Dir.home, ".mcp_rails.yml")).and_return(false)
      allow(File).to receive(:exist?).with(File.join(Dir.pwd, ".mcp_rails.yml")).and_return(false)
      expect(described_class.find_config_path).to eq(described_class.default_config_path)
    end

    it "returns home config when it exists" do
      home_config = File.join(Dir.home, ".mcp_rails.yml")
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(home_config).and_return(true)
      expect(described_class.find_config_path).to eq(home_config)
    end

    it "returns local config when it exists and home config doesn't" do
      home_config = File.join(Dir.home, ".mcp_rails.yml")
      local_config = File.join(Dir.pwd, ".mcp_rails.yml")
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(home_config).and_return(false)
      allow(File).to receive(:exist?).with(local_config).and_return(true)
      expect(described_class.find_config_path).to eq(local_config)
    end
  end

  describe ".load" do
    it "loads default config file" do
      config = described_class.load
      expect(config).to be_a(Hash)
      expect(config["server"]).to be_a(Hash)
      expect(config["server"]["name"]).to eq("RubyCodingRules")
    end

    it "loads custom config path when provided" do
      Dir.mktmpdir do |dir|
        custom_config = File.join(dir, "custom.yml")
        File.write(custom_config, "server:\n  name: TestServer\n  version: 1.0.0\ntools: []\nprompts: []\n")
        config = described_class.load(config_path: custom_config)
        expect(config["server"]["name"]).to eq("TestServer")
      end
    end

    it "raises error for missing config file" do
      expect { described_class.load(config_path: "/nonexistent/file.yml") }.to raise_error(SystemExit)
    end
  end

  describe ".server_manifest" do
    let(:config) { described_class.load }

    it "builds server manifest with name and version" do
      manifest = described_class.server_manifest(config)
      expect(manifest["name"]).to eq("RubyCodingRules")
      expect(manifest["version"]).to eq("1.0.0")
    end

    it "includes tools in manifest" do
      manifest = described_class.server_manifest(config)
      expect(manifest["tools"]).to be_an(Array)
      expect(manifest["tools"].first).to have_key("name")
      expect(manifest["tools"].first).to have_key("description")
    end
  end

  describe ".build_prompts" do
    let(:config) { described_class.load }

    it "builds prompts array" do
      prompts = described_class.build_prompts(config)
      expect(prompts).to be_an(Array)
      expect(prompts.first).to have_key("name")
      expect(prompts.first).to have_key("description")
    end
  end
end
