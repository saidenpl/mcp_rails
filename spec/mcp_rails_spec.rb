# frozen_string_literal: true

require "spec_helper"

RSpec.describe MCPRails do
  describe ".run" do
    it "loads config and starts server" do
      expect(MCPRails::Config).to receive(:load).and_return({})
      expect(MCPRails::Config).to receive(:server_manifest).and_return({})
      expect(MCPRails::Config).to receive(:build_prompts).and_return([])
      expect(MCPRails::Server).to receive(:run)
      MCPRails.run
    end
  end
end
