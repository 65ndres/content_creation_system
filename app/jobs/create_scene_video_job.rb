class CreateSceneVideoJob < ApplicationJob
  queue_as :default

  def perform(*args)
    scene = args.first
    Rails.logger.info("CreateSceneVideoJob scene=#{scene.id}")
    VideoEditorClient.create_scene_video(scene)
  end
end
