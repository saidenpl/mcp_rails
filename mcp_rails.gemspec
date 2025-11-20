# frozen_string_literal: true

require_relative "lib/mcp_rails/version"

Gem::Specification.new do |spec|
  spec.name = "mcp_rails"
  spec.version = MCPRails::VERSION
  spec.authors = ["Your Name"]
  spec.email = ["your.email@example.com"]

  spec.summary = "MCP server for Ruby/Rails coding rules and best practices"
  spec.description = "A Model Context Protocol (MCP) server that provides Ruby/Rails coding rules, best practices, and prompt templates for Cursor IDE"
  spec.homepage = "https://github.com/yourusername/mcp_rails"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "#{spec.homepage}.git"
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/master/CHANGELOG.md"

  spec.files = Dir.chdir(__dir__) do
    files = `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)}) || !File.exist?(f)
    end
    files << "mcp_rails.yml" if File.exist?("mcp_rails.yml") && !files.include?("mcp_rails.yml")
    files
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
end
