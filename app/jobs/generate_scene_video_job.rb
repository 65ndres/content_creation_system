class GenerateSceneVideoJob < ApplicationJob
  queue_as :default

  def perform(*args)
    scene = args.first
    Rails.logger.info("GenerateSceneVideoJob scene=#{scene.id}")
    VideoEditorClient.generate_scene_video(scene)
  end
end
