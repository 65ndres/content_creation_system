require "test_helper"
require "minitest/mock"

class StoryQueueTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def new_story(**attrs)
    Story.create!({ story_type: story_types(:one), source: sources(:one), image_generation_model: "lucid" }.merge(attrs))
  end

  test "the first story starts and the next ones wait in line" do
    first = second = third = nil
    assert_enqueued_jobs 1, only: CreateStoryTextJob do
      first  = new_story
      second = new_story
      third  = new_story
    end

    assert first.reload.queue_running?
    assert first.started_at.present?
    assert second.reload.queue_queued?
    assert third.reload.queue_queued?
    assert_equal 1, StoryQueue.position(second)
    assert_equal 2, StoryQueue.position(third)
    assert_nil StoryQueue.position(first)
  end

  test "finishing the running story starts the oldest queued one" do
    first  = new_story
    second = new_story
    third  = new_story

    assert_enqueued_with(job: CreateStoryTextJob, args: [ second ]) do
      first.reload.finish_in_queue!
    end

    assert first.reload.queue_done?
    assert first.finished_at.present?
    assert second.reload.queue_running?
    assert third.reload.queue_queued?
  end

  test "a failure frees the slot and records why" do
    first  = new_story
    second = new_story

    first.reload.fail_in_queue!("Final video render failed")

    assert first.reload.queue_failed?
    assert_equal "Final video render failed", first.last_error
    assert second.reload.queue_running?
  end

  test "a failure on a story that is not running leaves it alone" do
    story = stories(:one)
    story.fail_in_queue!("Scene #1: Leonardo video failed")

    assert story.reload.queue_done?
    assert_nil story.last_error
  end

  test "advance never starts more than the concurrency allows" do
    new_story
    new_story

    assert_no_enqueued_jobs only: CreateStoryTextJob do
      assert_empty StoryQueue.advance!
      assert_empty StoryQueue.advance!
    end
    assert_equal 1, Story.queue_running.count
  end

  test "cancelling a queued story takes it out of line" do
    first  = new_story
    second = new_story
    third  = new_story

    assert second.reload.cancel_in_queue!
    assert second.reload.queue_cancelled?

    first.reload.finish_in_queue!
    assert third.reload.queue_running?
  end

  test "cancelling the running story starts the next one" do
    first  = new_story
    second = new_story

    assert first.reload.cancel_in_queue!
    assert first.reload.queue_cancelled?
    assert second.reload.queue_running?
  end

  test "retry puts a failed story at the back of the line" do
    first  = new_story
    second = new_story
    third  = new_story
    first.reload.fail_in_queue!("boom")

    assert first.reload.retry_in_queue!
    assert first.reload.queue_queued?
    assert_nil first.last_error
    assert_equal 2, StoryQueue.position(first)
    assert_equal 1, StoryQueue.position(third.reload)
    assert second.reload.queue_running?
  end

  test "a retried story with scenes resumes instead of writing a new script" do
    story = new_story
    scene = Scene.create!(story: story, text: "Jesus said to his disciples.", ai_image_prompt: [ "a prompt" ],
                          images_total: 1, leonardo_video_gen_id: "stale-gen")
    story.reload.fail_in_queue!("Scene ##{scene.id}: Leonardo video failed")
    clear_enqueued_jobs

    story.retry_in_queue!

    assert story.reload.queue_running?
    assert_no_enqueued_jobs only: CreateStoryTextJob
    assert_enqueued_with(job: CreateSceneImagesJob, args: [ scene ])
    assert_nil scene.reload.leonardo_video_gen_id
  end

  test "the watchdog fails a story with no progress and starts the next one" do
    first  = new_story
    second = new_story
    first.reload.update_columns(started_at: 2.hours.ago, updated_at: 2.hours.ago)

    StoryQueue.fail_stalled!

    assert first.reload.queue_failed?
    assert_match(/Stalled/, first.last_error)
    assert second.reload.queue_running?
  end

  test "the watchdog leaves a story that is still making progress" do
    first = new_story
    first.reload.update_columns(started_at: 2.hours.ago, updated_at: 2.hours.ago)
    Scene.create!(story: first, text: "A scene that just changed.", ai_image_prompt: [ "p" ], images_total: 1)

    StoryQueue.fail_stalled!

    assert first.reload.queue_running?
  end

  test "the watchdog job schedules its next run" do
    assert_enqueued_with(job: StoryQueueWatchdogJob) do
      StoryQueueWatchdogJob.perform_now
    end
  end

  test "a finished final video marks the story done" do
    story = new_story
    story.reload.update_columns(video_gen_id: "gen-1")

    VideoEditorClient.stub(:generation_status, { "completed" => true, "file_path" => "/videos/final.mp4" }) do
      VideoEditorClient.is_story_video_ready(story)
    end

    assert story.reload.queue_done?
    assert_equal "/videos/final.mp4", story.video_url
  end

  test "a failed final video marks the story failed" do
    story = new_story
    story.reload.update_columns(video_gen_id: "gen-1")

    VideoEditorClient.stub(:generation_status, { "failed" => true }) do
      VideoEditorClient.is_story_video_ready(story)
    end

    assert story.reload.queue_failed?
    assert_equal "Final video render failed", story.last_error
  end

  test "a story without auto-produce gives up its turn once its scenes exist" do
    story = new_story(auto_produce: false)
    second = new_story
    response = { "pairs" => [ { "original" => "Jesus said to his disciples: be watchful.", "aiImagePrompts" => [ "a prompt" ] } ] }.to_json

    ChatGPTClient.stub(:generate_scene_images_prompts, response) do
      story.reload.create_scenes
    end

    assert story.reload.queue_done?
    assert second.reload.queue_running?
  end

  test "a story whose scene step makes nothing fails" do
    story = new_story

    ChatGPTClient.stub(:generate_scene_images_prompts, { "pairs" => [] }.to_json) do
      story.reload.create_scenes
    end

    assert story.reload.queue_failed?
    assert_equal "No scenes were created", story.last_error
  end
end
