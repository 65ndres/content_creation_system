class StoryTypesController < ActionController::Base
  # index/show are dashboard pages; generate/create answer the New story type composer with JSON.
  layout -> { action_name.in?(%w[index show update_outro]) ? "dashboard" : false }
  wrap_parameters false

  def index
    @story_types = StoryType.includes(:outro_video).order(:name)
    @story_counts = Story.group(:story_type_id).count
  end

  def show
    load_story_type_page
  end

  # Attach, swap or remove (blank id) the outro played at the end of this type's videos.
  def update_outro
    @story_type = StoryType.find(params[:id])
    outro_id = params[:outro_video_id].presence
    outro = outro_id && OutroVideo.find_by(id: outro_id)

    if outro_id && outro.nil?
      flash.now[:alert] = "That outro video no longer exists."
      load_story_type_page
      return render :show, status: :unprocessable_entity
    end

    @story_type.update!(outro_video: outro)
    notice = outro ? "Outro set to “#{outro.name}”." : "Outro removed."
    redirect_to story_type_path(@story_type), notice: notice
  end

  def generate
    prompt = params[:prompt].to_s.strip
    if prompt.blank?
      return render json: { error: "Type something before sending it to ChatGPT." }, status: :unprocessable_entity
    end

    render json: ChatGPTClient.generate_story_type_draft(prompt)
  rescue StandardError => e
    Rails.logger.error("StoryTypesController#generate failed: #{e.message}")
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def create
    story_type = StoryType.new(story_type_params)
    if story_type.save
      render json: { id: story_type.id, name: story_type.name }
    else
      render json: { error: story_type.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  rescue StandardError => e
    Rails.logger.error("StoryTypesController#create failed: #{e.message}")
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def load_story_type_page
    @story_type ||= StoryType.includes(outro_video: { video_attachment: :blob }).find(params[:id])
    @outro_videos = OutroVideo.order(:name)
    @story_count = @story_type.stories.count
  end

  def story_type_params
    params.permit(
      :name,
      :story_prompt_text,
      :scenes_json_prompts,
      :visual_style,
      :image_width,
      :image_height,
      :output_width,
      :output_height,
      :scene_text_min_chars,
      :scene_text_max_chars,
      :voice_id,
      :outro_video_id
    )
  end
end
