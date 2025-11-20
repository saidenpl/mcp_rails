# frozen_string_literal: true

require_relative "mcp_rails/version"
require_relative "mcp_rails/config"
require_relative "mcp_rails/content"
require_relative "mcp_rails/server"

module MCPRails
  def self.run
    config = MCPRails::Config.load
    server_manifest = MCPRails::Config.server_manifest(config)
    prompts = MCPRails::Config.build_prompts(config)
    MCPRails::Server.run(config, server_manifest, prompts)
  end
end
