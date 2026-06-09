class StoryJsonNormalizer
  def self.normalize_pairs(data)
    pairs = case data
            when Hash then data["pairs"] || data[:pairs]
            when Array then data
            else []
            end

    pairs = pairs.values if pairs.is_a?(Hash)
    return [] unless pairs.is_a?(Array)

    pairs.select { |obj| obj.is_a?(Hash) }
  end

  def self.normalize_ai_image_prompts(value)
    case value
    when String then [value]
    when Array then value.map(&:to_s).reject(&:blank?)
    else []
    end
  end

  def self.normalize_characters(value)
    case value
    when Array
      value.each_with_index.filter_map { |item, i| normalize_character_entry(item, i) }
    when Hash
      value.map { |name, desc| normalize_character_entry([name, desc], nil) }.compact
    else
      []
    end
  end

  def self.normalize_character_entry(item, index)
    case item
    when Hash
      name = item["name"] || item[:name]
      description = item["physical_description"] || item[:physical_description]
      return nil if name.blank? && description.blank?

      { "name" => name.to_s.presence || "Character #{index.to_i + 1}",
        "physical_description" => description.to_s }
    when String
      name, description = item.split(":", 2).map(&:strip)
      { "name" => name.presence || "Character #{index.to_i + 1}",
        "physical_description" => description.presence || item }
    when Array
      name, description = item
      if description.is_a?(Hash)
        description = description["physical_description"] || description[:physical_description] || description.values.join(" ")
      end
      normalize_character_entry({ "name" => name, "physical_description" => description }, index)
    end
  end
  private_class_method :normalize_character_entry
end
