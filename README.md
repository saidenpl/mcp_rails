# MCP Rails Configuration Documentation

## Overview

`mcp_rails.yml` is the configuration file for the Ruby MCP (Model Context Protocol) server. It defines the server metadata, available tools, and prompt templates used by Cursor IDE for Ruby/Rails development assistance.

## File Structure

### Server Configuration

```yaml
server:
  name: RubyCodingRules
  version: 1.0.0
```

**Fields:**
- `name` (String): Server identifier name
- `version` (String): Server version number

### Tools

Tools are executable functions that return content directly.

#### `get_cursor_coding_rules`

Returns Ruby/Rails coding rules and best practices.

**Input Schema:**
- Type: `object`
- Properties: `{}` (no parameters required)
- Required: `[]`

**Content Structure:**
- `title` (String): Main heading for the guidelines
- `intro` (String): Introduction text (must be quoted if ending with colon)
- `rules` (Array): List of coding rules
  - Each rule contains:
    - `name` (String): Rule title
    - `description` (String): Detailed explanation
- `footer` (String): Footer text

**Example Output:**
The server converts the structured `rules` array into markdown format with numbered list items.

### Prompts

Prompts are templates that generate instructions for the AI assistant.

#### `code_review`

Generates a code review prompt for Ruby/Rails code.

**Arguments:**
- `code` (String, required): The Ruby/Rails code to review
- `focus_areas` (String, optional): Specific areas to focus on (performance, security, style, SOLID, etc.)

**Template Variables:**
- `{{code}}`: The code to review
- `{{focus_areas}}`: Optional focus areas (conditionally rendered)

**Usage:**
The prompt checks for StandardRB compliance, SOLID principles, service object patterns, N+1 queries, proper error handling, and Rails best practices.

#### `refactor_suggestion`

Generates a refactoring suggestion prompt for Ruby code.

**Arguments:**
- `code` (String, required): The Ruby/Rails code to refactor

**Template Variables:**
- `{{code}}`: The code to refactor

**Focus Areas:**
- Extracting service objects
- Applying SOLID principles
- Improving readability
- Reducing complexity
- Following Rails conventions

#### `generate_documentation`

Generates a documentation generation prompt for Ruby code.

**Arguments:**
- `code` (String, required): The Ruby code to document

**Template Variables:**
- `{{code}}`: The code to document

**Output Format:**
Generates RDoc/YARD style documentation with method descriptions, parameter types, return values, and usage examples.

## Template Syntax

The prompts use a custom template syntax similar to Handlebars:

- `{{variable}}`: Variable substitution
- `{{#if variable}}...{{/if}}`: Conditional rendering
- Variables are replaced with their values or removed if empty/null

## YAML Formatting Notes

- Most strings don't require quotes unless they contain special characters
- Strings ending with colons (`:`) should be quoted to avoid YAML parsing issues
- Version numbers can be unquoted (treated as strings by YAML)
- Multiline strings use the `|` literal block scalar

## Coding Rules Defined

1. **Service Objects**: Prefer service objects in `app/services/` with single `call` method
2. **Standard Ruby Style**: Follow StandardRB rules, keyword arguments, hash shorthand
3. **SOLID Principles**: Keep classes focused and under 100 lines
4. **Rails Conventions**: ActiveRecord queries, avoid N+1, prefer scopes, never use concerns
5. **Testing**: RSpec with verified tag, prefer mocks/stubs, minimal expectations

## Integration

This configuration file is loaded by `mcp_rails.rb` which:
1. Parses the YAML file
2. Converts structured tool content to markdown
3. Renders prompt templates with provided arguments
4. Serves tools and prompts via JSON-RPC protocol

## Usage Example

```bash
# Call the tool via MCP server
{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"get_cursor_coding_rules"}}

# Get a prompt
{"jsonrpc":"2.0","id":2,"method":"prompts/get","params":{"name":"code_review","arguments":{"code":"class MyClass\nend"}}}
```

## Maintenance

When adding new rules:
1. Add to the `rules` array under `tools[0].content`
2. Follow the `name`/`description` structure
3. The server automatically converts to markdown

When adding new prompts:
1. Add to the `prompts` array
2. Define `name`, `description`, `arguments`, and `template`
3. Use template variables for dynamic content
