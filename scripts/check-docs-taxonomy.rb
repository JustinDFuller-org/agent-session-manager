#!/usr/bin/env ruby

require "yaml"

ROOT = File.expand_path("..", __dir__)
PUBLIC_TYPES = {
  "tutorials" => "tutorial",
  "how-to" => "how-to",
  "reference" => "reference",
  "explanation" => "explanation"
}.freeze

errors = []
pages = []

def front_matter(path)
  lines = File.readlines(path)
  return nil unless lines.first&.strip == "---"

  closing_index = lines[1..].index { |line| line.strip == "---" }
  return nil unless closing_index

  YAML.safe_load(
    lines[1..closing_index].join,
    permitted_classes: [],
    aliases: false
  ) || {}
end

PUBLIC_TYPES.each do |directory, expected_type|
  pattern = File.join(ROOT, "documentation", directory, "*.md")
  Dir[pattern].sort.each do |path|
    metadata = front_matter(path)
    relative_path = path.delete_prefix("#{ROOT}/")
    unless metadata
      errors << "#{relative_path}: missing YAML front matter"
      next
    end

    if metadata["diataxis_type"] != expected_type
      errors << "#{relative_path}: expected diataxis_type #{expected_type.inspect}, got #{metadata["diataxis_type"].inspect}"
    end

    permalink = metadata["permalink"]
    if permalink.to_s.empty?
      errors << "#{relative_path}: missing permalink"
    else
      pages << [relative_path, permalink]
    end
  end
end

legacy_directory = File.join(ROOT, "documentation", "user-guide")
unless !Dir.exist?(legacy_directory) || Dir.empty?(legacy_directory)
  errors << "documentation/user-guide must remain empty after the source migration"
end

navigation_path = File.join(ROOT, "_data", "navigation.yml")
navigation = YAML.safe_load(
  File.read(navigation_path),
  permitted_classes: [],
  aliases: false
) || []

navigation_urls = []
navigation.each do |group|
  group_type = group["type"]
  unless PUBLIC_TYPES.value?(group_type)
    errors << "navigation group #{group["title"].inspect} has invalid type #{group_type.inspect}"
  end

  (group["items"] || []).each do |item|
    item_type = item["type"]
    if item_type != group_type
      errors << "navigation item #{item["title"].inspect} does not match group type #{group_type.inspect}"
    end
    navigation_urls << item["url"]
  end
end

page_urls = pages.map(&:last)
page_url_counts = page_urls.each_with_object(Hash.new(0)) do |url, counts|
  counts[url] += 1
end
page_url_counts.each do |url, count|
  errors << "public permalink #{url.inspect} is declared #{count} times" if count > 1
end

(page_urls - navigation_urls).each do |url|
  errors << "public page permalink #{url.inspect} is missing from navigation"
end

(navigation_urls - page_urls).each do |url|
  errors << "navigation URL #{url.inspect} does not match a public page"
end

if errors.empty?
  puts "Diátaxis documentation taxonomy passed (#{pages.length} public pages)."
else
  errors.each { |error| warn "error: #{error}" }
  exit 1
end
