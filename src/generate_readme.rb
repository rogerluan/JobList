# frozen_string_literal: true

require "json"
require "erb"

# Load the data from the JSON file
json_data = File.read("data_sources.json")
data = JSON.parse(json_data)

# Append "?ref=rogeroba" to all URLs in the boards
[data["boards"], data["tools"], data["other_lists"]].each do |list|
  list.each do |item|
    item["url_with_ref"] = "#{item["url"]}?ref=rogeroba"
  end
end

# Read the README template
template = File.read("src/README.md.erb")
erb_template = ERB.new(template, trim_mode: "-")

# Generate README.md
File.write("README.md", erb_template.result_with_hash(data))
