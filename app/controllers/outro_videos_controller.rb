class OutroVideosController < ActionController::Base
  layout "dashboard"

  def index
    load_outro_videos
    @outro_video = OutroVideo.new
  end

  def create
    @outro_video = OutroVideo.new(outro_video_params)

    if @outro_video.save
      redirect_to outro_videos_path, notice: "Uploaded “#{@outro_video.name}”."
    else
      load_outro_videos
      render :index, status: :unprocessable_entity
    end
  end

  private

  def load_outro_videos
    @outro_videos = OutroVideo.with_attached_video.includes(:story_types).order(created_at: :desc)
  end

  def outro_video_params
    params.fetch(:outro_video, {}).permit(:name, :video)
  end
end
