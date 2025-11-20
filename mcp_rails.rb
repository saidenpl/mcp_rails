# frozen_string_literal: true

require "json"
require "yaml"

module MCP
  def self.run
    config = MCP::Config.load
    server_manifest = MCP::Config.server_manifest(config)
    prompts = MCP::Config.build_prompts(config)
    MCP::Server.run(config, server_manifest, prompts)
  end
end

module MCP::Config
  CONFIG_FILE = File.join(File.dirname(__FILE__), "mcp_rails.yml")

  module_function

  def load
    validate_file_exists
    parse_config
  rescue Psych::SyntaxError => e
    error("Failed to parse config file: #{e.message}")
  rescue => e
    error("Failed to load config file: #{e.message}")
  end

  def validate_file_exists
    return if File.exist?(CONFIG_FILE)

    error("Config file not found: #{CONFIG_FILE}")
  end

  def parse_config
    YAML.load_file(CONFIG_FILE)
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

module MCP::Content
  module_function

  def render_template(template, variables)
    template.dup
      .then { |result| process_conditionals(result, variables) }
      .then { |result| replace_variables(result, variables) }
      .then { |result| cleanup_remaining_variables(result) }
  end

  def process_conditionals(template, variables)
    template.gsub(/\{\{#if\s+(\w+)\}\}(.*?)\{\{\/if\}\}/m) do |_match|
      var_name = $1
      content = $2
      should_include?(variables[var_name]) ? content : ""
    end
  end

  def should_include?(value)
    return false unless value
    return false if value.to_s.empty?
    return false if %w[auto-detect general].include?(value.to_s)

    true
  end

  def replace_variables(template, variables)
    variables.each_with_object(template.dup) do |(key, value), result|
      escaped_key = Regexp.escape(key)
      result.gsub!(/\{\{#{escaped_key}\}\}/, value.to_s)
    end
  end

  def cleanup_remaining_variables(template)
    template.gsub(/\{\{[^}]+\}\}/, "")
  end

  def get_tool(config, tool_name)
    tool_config = find_tool(config, tool_name)
    return nil unless tool_config

    build_tool_response(tool_config)
  end

  def find_tool(config, tool_name)
    config["tools"].find { |t| t["name"] == tool_name }
  end

  def build_tool_response(tool_config)
    content = tool_config["content"]
    markdown = if content["markdown"]
      content["markdown"]
    else
      build_markdown_from_structure(content)
    end

    {
      "content" => [
        {
          "type" => "text",
          "text" => markdown
        }
      ]
    }
  end

  def build_markdown_from_structure(content)
    parts = []
    parts << "### #{content["title"]}" if content["title"]
    parts << "" if content["title"]
    parts << content["intro"] if content["intro"]
    parts << "" if content["intro"]

    if content["rules"] && content["rules"].is_a?(Array)
      content["rules"].each_with_index do |rule, index|
        parts << "#{index + 1}.  **#{rule["name"]}:** #{rule["description"]}"
      end
    end

    parts << "" if content["footer"]
    parts << "---" if content["footer"]
    parts << "*#{content["footer"]}*" if content["footer"]

    parts.join("\n")
  end

  def get_prompt(config, prompt_name, arguments)
    prompt_config = find_prompt(config, prompt_name)
    return nil unless prompt_config

    variables = set_defaults(prompt_config, arguments)
    rendered_text = render_template(prompt_config["template"], variables)
    build_prompt_response(rendered_text)
  end

  def find_prompt(config, prompt_name)
    config["prompts"].find { |p| p["name"] == prompt_name }
  end

  def set_defaults(prompt_config, arguments)
    variables = arguments.dup
    prompt_config["arguments"].each do |arg|
      arg_name = arg["name"]
      next if variables.key?(arg_name) && !variables[arg_name].nil?

      variables[arg_name] = default_value_for(arg_name)
    end
    variables
  end

  def default_value_for(arg_name)
    case arg_name
    when "focus_areas"
      "general"
    when "language"
      "auto-detect"
    when "format"
      "markdown"
    else
      ""
    end
  end

  def build_prompt_response(text)
    {
      "messages" => [
        {
          "role" => "user",
          "content" => {
            "type" => "text",
            "text" => text
          }
        }
      ]
    }
  end
end

module MCP::Server
  PROTOCOL_VERSION = "2024-11-05"
  JSON_RPC_VERSION = "2.0"

  ERROR_CODES = {
    parse_error: -32700,
    invalid_request: -32600,
    method_not_found: -32601,
    invalid_params: -32602,
    internal_error: -32000
  }.freeze

  module_function

  def run(config, server_manifest, prompts)
    log_startup
    STDIN.each_line { |line| process_request(line, config, server_manifest, prompts) }
  end

  def log_startup
    warn "Ruby MCP Server (RubyCodingRules) started. Waiting for requests on STDIN..."
  end

  def process_request(line, config, server_manifest, prompts)
    request = parse_request(line)
    return unless request

    handle_request(request, config, server_manifest, prompts)
  rescue JSON::ParserError
    log_error("Failed to parse JSON input.")
  rescue => e
    handle_fatal_error(e, request&.dig("id"))
  end

  def parse_request(line)
    JSON.parse(line)
  end

  def handle_request(request, config, server_manifest, prompts)
    id = request["id"]
    method = request["method"]
    params = request["params"] || {}

    return handle_notification(method) if id.nil?
    return handle_missing_method(id) unless method

    log_request(id, method)
    route_request(id, method, params, config, server_manifest, prompts)
  end

  def handle_notification(method)
    log_notification(method)
    nil
  end

  def log_notification(method)
    warn "<- Received #{method} notification."
  end

  def handle_missing_method(id)
    send_error_response(id, ERROR_CODES[:invalid_request], "Invalid Request: missing 'method'")
    nil
  end

  def log_request(id, method)
    warn "-> Received request (ID: #{id}, Method: #{method})"
  end

  def route_request(id, method, params, config, server_manifest, prompts)
    case method
    when "initialize"
      handle_initialize(id, server_manifest)
    when "initialized"
      handle_initialized
    when "tools/list"
      handle_tools_list(id, server_manifest)
    when "tools/call"
      handle_tools_call(id, params, config)
    when "prompts/list"
      handle_prompts_list(id, prompts)
    when "prompts/get"
      handle_prompts_get(id, params, config)
    else
      handle_unknown_method(id, method)
    end
  end

  def handle_initialize(id, server_manifest)
    send_response(id, build_initialize_response(server_manifest))
    log_response("initialize")
  end

  def build_initialize_response(server_manifest)
    {
      "protocolVersion" => PROTOCOL_VERSION,
      "capabilities" => {
        "tools" => {"listChanged" => false},
        "prompts" => {"listChanged" => false}
      },
      "serverInfo" => {
        "name" => server_manifest["name"],
        "version" => server_manifest["version"]
      }
    }
  end

  def handle_initialized
    log_notification("initialized")
  end

  def handle_tools_list(id, server_manifest)
    response = {"tools" => server_manifest["tools"]}
    log_tools_list(server_manifest["tools"])
    send_response(id, response)
  end

  def log_tools_list(tools)
    warn "<- Sending tools/list response with #{tools.length} tool(s)"
    warn "<- Tools: #{tools.map { |t| t["name"] }.join(", ")}"
  end

  def handle_tools_call(id, params, config)
    tool_name = params["name"]
    return handle_missing_tool_name(id) unless tool_name

    result = MCP::Content.get_tool(config, tool_name)
    if result
      send_response(id, result)
      log_response("tools/call", tool_name)
    else
      handle_unknown_tool(id, tool_name)
    end
  end

  def handle_missing_tool_name(id)
    send_error_response(id, ERROR_CODES[:invalid_params], "Invalid params: missing 'name'")
  end

  def handle_unknown_tool(id, tool_name)
    error_message = "Unknown tool: #{tool_name}"
    send_error_response(id, ERROR_CODES[:method_not_found], error_message)
    log_error(error_message)
  end

  def handle_prompts_list(id, prompts)
    response = {"prompts" => prompts}
    log_prompts_list(prompts)
    send_response(id, response)
  end

  def log_prompts_list(prompts)
    warn "<- Sending prompts/list response with #{prompts.length} prompt(s)"
    warn "<- Prompts: #{prompts.map { |p| p["name"] }.join(", ")}"
  end

  def handle_prompts_get(id, params, config)
    prompt_name = params["name"]
    prompt_arguments = params["arguments"] || {}
    return handle_missing_prompt_name(id) unless prompt_name

    result = MCP::Content.get_prompt(config, prompt_name, prompt_arguments)
    if result
      send_response(id, result)
      log_response("prompts/get", prompt_name)
    else
      handle_unknown_prompt(id, prompt_name)
    end
  end

  def handle_missing_prompt_name(id)
    send_error_response(id, ERROR_CODES[:invalid_params], "Invalid params: missing 'name'")
  end

  def handle_unknown_prompt(id, prompt_name)
    error_message = "Unknown prompt: #{prompt_name}"
    send_error_response(id, ERROR_CODES[:method_not_found], error_message)
    log_error(error_message)
  end

  def handle_unknown_method(id, method)
    error_message = "Unknown JSON-RPC method: #{method}"
    send_error_response(id, ERROR_CODES[:method_not_found], error_message)
    log_error(error_message)
  end

  def send_response(id, result = nil, error = nil)
    return if id.nil?

    response = build_response(id, result, error)
    output_response(response)
  end

  def build_response(id, result, error)
    response = {"jsonrpc" => JSON_RPC_VERSION, "id" => id}
    response["error"] = error if error
    response["result"] = result
    response
  end

  def send_error_response(id, code, message)
    error_object = {"code" => code, "message" => message}
    send_response(id, nil, error_object)
  end

  def output_response(response)
    json_output = JSON.generate(response)
    puts json_output
    $stdout.flush
    warn "   JSON output: #{json_output}" if ENV["MCP_DEBUG"]
  end

  def log_response(method, detail = nil)
    message = detail ? "<- Sent #{method} response for #{detail}." : "<- Sent #{method} response."
    warn message
  end

  def log_error(message)
    warn "<- Sent error response: #{message}"
  end

  def handle_fatal_error(error, id)
    warn "**FATAL ERROR**: #{error.message}\n#{error.backtrace.join("\n")}"
    send_error_response(id, ERROR_CODES[:internal_error], "Server execution error: #{error.message}") if id
  end
end

MCP.run
