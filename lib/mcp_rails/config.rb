# frozen_string_literal: true

require "yaml"

module MCPRails
  module Config
    module_function

    def load(config_path: nil)
      path = config_path || find_config_path
      validate_file_exists(path)
      parse_config(path)
    rescue Psych::SyntaxError => e
      error("Failed to parse config file: #{e.message}")
    rescue => e
      error("Failed to load config file: #{e.message}")
    end

    def find_config_path
      begin
        home_config = File.join(Dir.home, ".mcp_rails.yml")
        return home_config if File.exist?(home_config)
      rescue ArgumentError
      end

      local_config = File.join(Dir.pwd, ".mcp_rails.yml")
      return local_config if File.exist?(local_config)

      default_config_path
    end

    def default_config_path
      File.join(File.dirname(__FILE__), "..", "..", "mcp_rails.yml")
    end

    def validate_file_exists(config_path)
      return if File.exist?(config_path)

      error("Config file not found: #{config_path}")
    end

    def parse_config(config_path)
      YAML.load_file(config_path)
    end

    def error(message)
      warn "**ERROR**: #{message}"
      exit 1
    end

    def server_manifest(config)
      {
        "name" => config["server"]["name"],
        "version" => config["server"]["version"],
        "tools" => build_tools(config)
      }
    end

    def build_tools(config)
      config["tools"].map do |tool|
        {
          "name" => tool["name"],
          "description" => tool["description"],
          "inputSchema" => tool["inputSchema"]
        }
      end
    end

    def build_prompts(config)
      config["prompts"].map do |prompt|
        {
          "name" => prompt["name"],
          "description" => prompt["description"],
          "arguments" => prompt["arguments"]
        }
      end
    end
  end
end
