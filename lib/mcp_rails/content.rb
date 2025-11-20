# frozen_string_literal: true

module MCPRails
  module Content
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
      markdown = content["markdown"] || build_markdown_from_structure(content)

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

      if content["rules"]&.is_a?(Array)
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
end
