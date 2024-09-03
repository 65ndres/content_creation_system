class CreateSceneVideoJob < ApplicationJob
  queue_as :default

  def perform(*args)
    scene = args.first
    Json2videoClient.create_scene_video(scene)
  end
end
