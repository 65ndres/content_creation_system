# Streams videos that video_editor wrote to local disk. Scenes and stories store
# those files as absolute paths, which the browser can't load directly.
class MediaController < ActionController::Base
  # Override with VIDEO_EDITOR_MEDIA_PATH when video_editor writes elsewhere (its OUTPUT_MEDIA_PATH).
  def self.media_root
    @media_root ||= File.realpath(ENV["VIDEO_EDITOR_MEDIA_PATH"].presence || Rails.root.join("..", "video_editor").to_s)
  end

  def scene
    scene = Scene.find(params[:id])
    stream_local_file(params[:kind] == "merged" ? scene.merged_audio_video_url : scene.video_url)
  end

  def story
    stream_local_file(Story.find(params[:id]).video_url)
  end

  private

  def stream_local_file(path)
    real_path = File.realpath(path.to_s) rescue nil
    return head :not_found unless real_path&.start_with?("#{self.class.media_root}/") && File.file?(real_path)

    # Rack::Files answers Range requests, so the browser can seek in the video.
    status, headers, body = Rack::Files.new(File.dirname(real_path)).serving(request, real_path)
    response.headers.merge!(headers)
    self.status = status
    self.response_body = body
  end
end
