class LeonardoCreateSceneVideoJob < ApplicationJob
  queue_as :default

  def perform(*args)
    scene = args.first
    Rails.logger.info("LeonardoCreateSceneVideoJob scene=#{scene.id}")
    LeonardoClient.generate_scene_video(scene)
  end
end