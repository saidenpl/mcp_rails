# frozen_string_literal: true

require "spec_helper"

RSpec.describe MCPRails::Content do
  describe ".render_template" do
    it "replaces variables in template" do
      template = "Hello {{name}}!"
      variables = {"name" => "World"}
      result = described_class.render_template(template, variables)
      expect(result).to eq("Hello World!")
    end

    it "handles conditional blocks" do
      template = "Start{{#if show}}Middle{{/if}}End"
      result = described_class.render_template(template, {"show" => "yes"})
      expect(result).to eq("StartMiddleEnd")
    end

    it "removes conditional blocks when condition is false" do
      template = "Start{{#if show}}Middle{{/if}}End"
      result = described_class.render_template(template, {"show" => ""})
      expect(result).to eq("StartEnd")
    end

    it "removes unused variables" do
      template = "Hello {{name}} and {{unused}}!"
      variables = {"name" => "World"}
      result = described_class.render_template(template, variables)
      expect(result).to eq("Hello World and !")
    end
  end

  describe ".get_tool" do
    let(:config) { MCPRails::Config.load }

    it "returns tool content for existing tool" do
      result = described_class.get_tool(config, "get_cursor_coding_rules")
      expect(result).to be_a(Hash)
      expect(result["content"]).to be_an(Array)
      expect(result["content"].first["type"]).to eq("text")
    end

    it "returns nil for non-existent tool" do
      result = described_class.get_tool(config, "nonexistent_tool")
      expect(result).to be_nil
    end
  end

  describe ".get_prompt" do
    let(:config) { MCPRails::Config.load }

    it "returns prompt messages for existing prompt" do
      result = described_class.get_prompt(config, "code_review", {"code" => "class Test; end"})
      expect(result).to be_a(Hash)
      expect(result["messages"]).to be_an(Array)
      expect(result["messages"].first["role"]).to eq("user")
    end

    it "applies default values for missing arguments" do
      result = described_class.get_prompt(config, "code_review", {"code" => "test"})
      expect(result["messages"].first["content"]["text"]).to include("test")
    end

    it "returns nil for non-existent prompt" do
      result = described_class.get_prompt(config, "nonexistent_prompt", {})
      expect(result).to be_nil
    end
  end

  describe ".build_markdown_from_structure" do
    it "builds markdown from structured content" do
      content = {
        "title" => "Test Title",
        "intro" => "Test intro",
        "rules" => [
          {"name" => "Rule 1", "description" => "Description 1"}
        ],
        "footer" => "Test footer"
      }
      result = described_class.build_markdown_from_structure(content)
      expect(result).to include("Test Title")
      expect(result).to include("Rule 1")
      expect(result).to include("Description 1")
    end
  end
end
