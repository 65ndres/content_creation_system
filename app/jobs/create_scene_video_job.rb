class CreateSceneVideoJob < ApplicationJob
  queue_as :default

  def perform(*args)
    scene = args.first
    Json2videoClient.create_scene_video(scene)
    # Call the Json2videoClient
    # Do something later
  end
end
