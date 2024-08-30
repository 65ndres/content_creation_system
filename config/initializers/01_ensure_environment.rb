if Rails.env.development?
    %w[
    CHATGPT_KEY
    ].each do |env_var|
      if !ENV.has_key?(env_var) || ENV[env_var].blank?
        raise <<~EOL
        Missing environment variable: #{env_var}
  
        Ask a teammate for the appropriate value.
        EOL
      end
    end
  end