# frozen_string_literal: true

require "json"
require "net/http"
require "uri"
require "progress_bar"

def load_data_sources
  JSON.parse(File.read("data_sources.json"))
end

# Returns 0 if the URL is OK, the response code if there's a redirect, or -1 if there's an error
def check_url(url)
  uri = URI(url)
  Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
    http.open_timeout = 10
    http.read_timeout = 10
    request = Net::HTTP::Get.new(uri)
    response = http.request(request)
    case response
      when Net::HTTPSuccess
        return 0
      when Net::HTTPRedirection
        location = response["location"]
        return check_url(location) # Follow the redirect
      else
        return response.code.to_i
    end
  end
  0
rescue StandardError
  -1
end

def append_ref(url)
  return url if url.nil? || url.empty?
  uri = URI(url)
  params = URI.decode_www_form(uri.query || "") << %w[ref rogeroba]
  uri.query = URI.encode_www_form(params)
  uri.to_s
end

def count_urls(data)
  data.values.sum do |category_data|
    if category_data.is_a?(Array)
      category_data.count { |item| item["url"] }
    elsif category_data.is_a?(Hash)
      count_urls(category_data)
    else
      0
    end
  end
end

def process_data_sources(data, bar)
  data.transform_values do |category_data|
    if category_data.is_a?(Array)
      category_data.map do |item|
        if item["skip_url_check"] == true || item["url"].nil? || item["url"].empty?
          bar.puts("⏩ Skipping URL check for #{item["name"]}")
          bar.increment!
          item
        else
          url_with_ref = append_ref(item["url"])
          bar.puts("🔍 Checking URL: '#{url_with_ref}'")
          response_code = check_url(url_with_ref)
          bar.puts("#{response_code.zero? ? "✅" : "❌"} Response code #{response_code.zero? ? "OK" : response_code} for #{item["name"]}")
          bar.increment!
          response_code.zero? ? item : nil
        end
      end.compact
    elsif category_data.is_a?(Hash)
      process_data_sources(category_data, bar)
    else
      category_data
    end
  end
end

data_sources = load_data_sources
total_urls = count_urls(data_sources)

bar = ProgressBar.new(total_urls)

updated_sources = process_data_sources(data_sources, bar)

puts "\n" # Add a newline after the progress bar

if updated_sources == data_sources
  puts "✅ No broken URLs found."
  exit(0)  # Exit with zero status to indicate no changes were made
else
  File.write("data_sources.json", JSON.pretty_generate(updated_sources))
  puts "❌ Broken URLs removed and data_sources.json updated."
  exit(1)  # Exit with non-zero status to indicate changes were made
end
