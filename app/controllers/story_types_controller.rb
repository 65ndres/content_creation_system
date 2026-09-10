class StoryTypesController < ActionController::Base
  layout false
  wrap_parameters false

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

  def story_type_params
    params.permit(
      :name,
      :story_prompt_text,
      :scenes_json_prompts,
      :image_width,
      :image_height,
      :output_width,
      :output_height,
      :scene_text_min_chars,
      :scene_text_max_chars
    )
  end
end
