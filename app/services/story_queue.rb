# Runs stories one at a time (Leonardo allows one pending generation, so stories running side by side
# trip over each other). New stories wait as "queued"; when the running story ends (done, failed,
# cancelled or stalled) the oldest queued story starts.
#
#   STORY_QUEUE_CONCURRENCY    how many stories may run at once (default 1)
#   STORY_QUEUE_STALL_MINUTES  a running story with no progress for this long is failed (default 45)
class StoryQueue
  # Any constant works; it only has to be the same for every process.
  LOCK_KEY = 4_172_026

  def self.concurrency
    ENV.fetch("STORY_QUEUE_CONCURRENCY", 1).to_i.clamp(1, 10)
  end

  def self.stall_after
    ENV.fetch("STORY_QUEUE_STALL_MINUTES", 45).to_i.clamp(5, 24 * 60).minutes
  end

  # Starts queued stories while a slot is free and returns them. The advisory lock keeps two
  # jobs finishing at the same moment from both starting the same story.
  def self.advance!
    started = []
    Story.transaction do
      Story.connection.execute("SELECT pg_advisory_xact_lock(#{LOCK_KEY})")
      free = concurrency - Story.queue_running.count
      if free.positive?
        Story.queue_waiting.limit(free).each do |story|
          now = Time.current
          story.update_columns(queue_state: "running", started_at: now, finished_at: nil, last_error: nil, updated_at: now)
          started << story
        end
      end
    end
    # Enqueue after the commit so the job sees the story as running.
    started.each { |story| start_pipeline(story) }
    started
  end

  # A story with no scenes starts from the text. One that was retried after a failure picks up
  # where it stopped instead of writing a new script (which would duplicate its scenes).
  def self.start_pipeline(story)
    if story.scenes.exists?
      story.resume_pipeline!
    else
      CreateStoryTextJob.perform_later(story)
    end
  end

  # Fails running stories whose story and scenes have not changed for stall_after. Most
  # pipeline failures only stop polling, so without this a broken story would hold the slot forever.
  def self.fail_stalled!
    minutes = (stall_after / 60).to_i
    Story.queue_running.select { |story| story.last_activity_at < stall_after.ago }.each do |story|
      story.fail_in_queue!("Stalled: no progress for #{minutes} minutes")
    end
  end

  def self.position(story)
    return unless story.queue_queued?

    Story.queue_waiting.where("queued_at < ? OR (queued_at = ? AND id < ?)", story.queued_at, story.queued_at, story.id).count + 1
  end
end
