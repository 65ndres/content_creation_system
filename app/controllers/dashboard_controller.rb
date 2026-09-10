class DashboardController < ActionController::Base
  layout "dashboard"
  helper_method :scene_audio_url, :scene_video_url, :story_status

  def index
    @stories = Story.includes(:story_type, :source, :scenes).order(created_at: :desc)
  end

  def new
    load_story_form
    @story = Story.new(
      image_generation_model: LeonardoClient::DEFAULT_IMAGE_MODEL
    )
  end

  def create
    @story = Story.new(story_params)
    @story.defer_pipeline = true

    if @story.save
      CreateStoryTextJob.perform_later(@story)
      redirect_to story_path(@story)
    else
      load_story_form
      render :new, status: :unprocessable_entity
    end
  rescue ArgumentError => e
    load_story_form
    @story ||= Story.new(story_params)
    @story.errors.add(:base, e.message)
    render :new, status: :unprocessable_entity
  end

  def show
    @story = Story.includes(:story_type, :source, scenes: { audio_attachment: :blob }).find(params[:id])
    @scenes = @story.scenes.order(:id)
  end

  def new_source
  end

  def new_story_type
  end

  private

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
      :video_generation_model
    )
    permitted[:video_generation_model] = permitted[:video_generation_model].presence
    permitted
  end

  def scene_audio_url(scene)
    return unless scene.audio.attached?

    rails_blob_path(scene.audio, only_path: true)
  end

  def scene_video_url(scene)
    scene.leonardo_video_url.presence || scene.video_url.presence
  end

  def story_status(story)
    return "Queued" if story.scenes.empty? && story.text.blank?
    return "Draft" if story.scenes.empty?
    return "Final video" if story.video_completed?
    return "Merged" if story.scenes_audio_video_merge_completed?
    return "Video ready" if story.scenes_video_generation_completed?
    return "Audio ready" if story.scenes_audio_files_completed?

    "Generating"
  end
end
