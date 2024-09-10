class CreateSceneVideoJob < ApplicationJob
  queue_as :default

  def perform(*args)
    scene = args.first
    puts "######## CreateSceneVideoJob #{scene} ########"
    Json2videoClient.create_scene_video(scene)
  end
end
