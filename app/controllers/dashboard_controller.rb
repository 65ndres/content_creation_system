class DashboardController < ActionController::Base
  layout "dashboard"
  helper_method :scene_audio_url, :scene_video_url, :scene_merged_video_url, :story_final_video_url, :story_status

  def index
    @stories = Story.includes(:story_type, :source, :scenes).order(created_at: :desc)
    @running = Story.queue_running.includes(:story_type).order(:started_at).to_a
    @waiting = Story.queue_waiting.includes(:story_type).to_a
    @failed  = Story.queue_failed.includes(:story_type).order(finished_at: :desc).limit(5).to_a
  end

  def new
    load_story_form
    @story = Story.new(
      image_generation_model: LeonardoClient::DEFAULT_IMAGE_MODEL
    )
  end

  # One story per picked source, all with the same settings. Each joins the story queue,
  # which starts them one at a time.
  def create
    source_ids = Array(params.dig(:story, :source_ids)).reject(&:blank?).uniq
    source_ids = [ story_params[:source_id] ].compact_blank if source_ids.empty?
    @story = Story.new(story_params.merge(source_id: source_ids.first))

    if source_ids.empty?
      @story.errors.add(:base, "Pick at least one source.")
      return render_new_story
    end

    stories = []
    Story.transaction do
      source_ids.each { |id| stories << Story.create!(story_params.merge(source_id: id)) }
    end

    if stories.one?
      redirect_to story_path(stories.first)
    else
      redirect_to stories_path, notice: "#{stories.size} stories queued. They run one at a time."
    end
  rescue ActiveRecord::RecordInvalid => e
    @story.errors.add(:base, e.record.errors.full_messages.to_sentence)
    render_new_story
  rescue ArgumentError => e
    @story ||= Story.new
    @story.errors.add(:base, e.message)
    render_new_story
  end

  def cancel_in_queue
    story = Story.find(params[:id])
    story.cancel_in_queue!
    redirect_back fallback_location: story_path(story)
  end

  def retry_in_queue
    story = Story.find(params[:id])
    story.retry_in_queue!
    redirect_back fallback_location: story_path(story)
  end

  def show
    @story = Story.includes(:story_type, :source, scenes: { audio_attachment: :blob }).find(params[:id])
    @scenes = @story.scenes.order(:id)
  end

  def generate_videos
    story = Story.find(params[:id])
    story.enqueue_scene_generations!
    redirect_to story_path(story)
  end

  def create_video
    story = Story.find(params[:id])
    if story.scenes_audio_video_merge_completed?
      story.update_columns(video_url: nil, video_gen_id: nil)
      CreateStoryVideoJob.perform_later(story)
    end
    redirect_to story_path(story)
  end

  def rebuild_scene_videos
    story = Story.find(params[:id])
    story.scenes.order(:id).each(&:rebuild_slideshow_video!)
    redirect_to story_path(story)
  end

  def new_source
  end

  def new_story_type
    @outro_videos = OutroVideo.order(:name)
  end

  private

  def render_new_story
    load_story_form
    render :new, status: :unprocessable_entity
  end

  def load_story_form
    @story_types = StoryType.order(:name)
    @sources = Source.order(created_at: :desc)
    @image_models = LeonardoClient::IMAGE_MODEL_CHOICES
    @video_models = LeonardoClient::VIDEO_MODEL_CHOICES
  end

  def story_params
    permitted = params.require(:story).permit(
      :story_type_id,
      :source_id,
      :image_generation_model,
      :video_generation_model,
      :auto_produce
    )
    permitted[:video_generation_model] = permitted[:video_generation_model].presence
    permitted
  end

  def scene_audio_url(scene)
    return unless scene.audio.attached?

    rails_blob_path(scene.audio, only_path: true)
  end

  def scene_video_url(scene)
    scene.leonardo_video_url.presence || playable_url(scene.video_url) { scene_media_path(scene, kind: "video") }
  end

  def scene_merged_video_url(scene)
    playable_url(scene.merged_audio_video_url) { scene_media_path(scene, kind: "merged") }
  end

  def story_final_video_url(story)
    playable_url(story.video_url) { story_media_path(story) }
  end

  # Remote URLs play as-is; local paths from video_editor go through MediaController.
  def playable_url(url)
    return if url.blank?

    url.match?(/\Ahttps?:\/\//i) ? url : yield
  end

  def story_status(story)
    return "Queued · ##{StoryQueue.position(story)} in line" if story.queue_queued?
    return "Cancelled" if story.queue_cancelled? && story.video_url.blank?
    return "Failed" if story.queue_failed?
    return "Starting" if story.scenes.empty? && story.text.blank?
    return "Draft" if story.scenes.empty?
    return "Final video" if story.video_completed?
    return "Merged" if story.scenes_audio_video_merge_completed?
    return "Video ready" if story.scenes_video_generation_completed?
    return "Audio ready" if story.scenes_audio_files_completed?

    "Generating"
  end
end
