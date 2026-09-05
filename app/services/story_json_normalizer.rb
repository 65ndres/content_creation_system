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

  def self.filter_characters_in_text(characters, *texts)
    haystack = texts.flatten.compact.join(" ")
    return [] if haystack.blank?

    normalize_characters(characters).select do |character|
      character_name_mentioned?(character["name"], haystack)
    end
  end

  def self.seed_characters(characters, text, limit: 3)
    normalized = normalize_characters(characters)
    return [] if normalized.blank?
    return normalized if normalized.size <= limit

    main = normalized.first
    others = normalized.drop(1).sort_by.with_index do |character, index|
      [-character_mention_count(character["name"], text.to_s), index]
    end

    [main, *others.first(limit - 1)]
  end

  def self.character_name_mentioned?(name, haystack)
    character_mention_count(name, haystack).positive?
  end
  private_class_method :character_name_mentioned?

  def self.character_mention_count(name, haystack)
    return 0 if name.blank?

    text = haystack.to_s
    return 0 if text.blank?

    count = text.scan(Regexp.new("\\b#{Regexp.escape(name)}\\b", Regexp::IGNORECASE)).size
    token = primary_match_token(name)
    if token.present? && !token.casecmp?(name)
      count += text.scan(Regexp.new("\\b#{Regexp.escape(token)}\\b", Regexp::IGNORECASE)).size
    end
    count
  end
  private_class_method :character_mention_count

  def self.primary_match_token(name)
    stripped = name.to_s.sub(/\A(?:unnamed|unknown)\s+/i, "")
    tokens = stripped.split(/\s+/).reject { |token| token.match?(/\A(?:the|a|an|at)\z/i) }
    significant = tokens.select { |token| token.gsub(/[^a-z0-9]/i, "").length >= 4 }
    return nil if significant.empty?

    return significant.first if name.match?(/\A(?:unnamed|unknown)\s+/i)
    return significant.last if significant.size > 1

    significant.first
  end
  private_class_method :primary_match_token

  def self.word_boundary_match?(haystack, term)
    pattern = Regexp.new("\\b#{Regexp.escape(term.to_s)}\\b", Regexp::IGNORECASE)
    haystack.match?(pattern)
  end
  private_class_method :word_boundary_match?

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
