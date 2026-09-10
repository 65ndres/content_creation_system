class SourcesController < ActionController::Base
  layout false
  wrap_parameters false

  def generate
    prompt = params[:prompt].to_s.strip
    if prompt.blank?
      return render json: { error: "Type something before sending it to ChatGPT." }, status: :unprocessable_entity
    end

    text = ChatGPTClient.generate_source_text(prompt)
    render json: { text: text }
  rescue StandardError => e
    Rails.logger.error("SourcesController#generate failed: #{e.message}")
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def create
    text = params[:text].to_s.strip
    if text.blank?
      return render json: { error: "Source text is empty." }, status: :unprocessable_entity
    end

    user = User.first
    unless user
      return render json: { error: "No user exists yet. Run db:seed first." }, status: :unprocessable_entity
    end

    source = user.sources.create!(text: text)
    render json: { id: source.id }
  rescue StandardError => e
    Rails.logger.error("SourcesController#create failed: #{e.message}")
    render json: { error: e.message }, status: :unprocessable_entity
  end
end
