redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/0")

Sidekiq.configure_server do |config|
  config.redis = { url: redis_url }
  config.logger = ActiveSupport::Logger.new(Rails.root.join("log", "sidekiq.log"))

  [$stdout, $stderr, STDOUT, STDERR].uniq.each { |io| io.extend(EpipeSafeIO) }
end

Sidekiq.configure_client do |config|
  config.redis = { url: redis_url }
end
