class LeonardoCreateSceneVideoJob < ApplicationJob
  queue_as :default

  def perform(*args)
    scene = args.first
    puts "######## CreateSceneVideoJob #{scene} ########"
    LeonardoClient.generate_scene_video(scene)
  end
end