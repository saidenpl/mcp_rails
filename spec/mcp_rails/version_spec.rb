# frozen_string_literal: true

require "spec_helper"

RSpec.describe MCPRails::VERSION do
  it "is a string" do
    expect(MCPRails::VERSION).to be_a(String)
  end

  it "matches semantic versioning pattern" do
    expect(MCPRails::VERSION).to match(/\d+\.\d+\.\d+/)
  end

  it "is not empty" do
    expect(MCPRails::VERSION).not_to be_empty
  end
end
