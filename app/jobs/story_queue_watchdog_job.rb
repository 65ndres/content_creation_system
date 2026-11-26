# Every few minutes: fail a running story that stopped making progress, then start the next one.
# Sidekiq runs it once on startup (config/initializers/sidekiq.rb), which also picks the queue back
# up after a restart; each run schedules the next.
class StoryQueueWatchdogJob < ApplicationJob
  queue_as :default

  INTERVAL = 5.minutes

  def perform
    StoryQueue.fail_stalled!
    StoryQueue.advance!
  ensure
    self.class.schedule_next
  end

  # Only one run stays scheduled, even after several restarts.
  def self.schedule_next
    return if already_scheduled?

    set(wait: INTERVAL).perform_later
  end

  def self.already_scheduled?
    return false unless queue_adapter.is_a?(ActiveJob::QueueAdapters::SidekiqAdapter)

    require "sidekiq/api"
    Sidekiq::ScheduledSet.new.any? { |job| job.display_class == name }
  rescue StandardError => e
    Rails.logger.warn("StoryQueueWatchdogJob: could not read the schedule (#{e.message})")
    false
  end
end
