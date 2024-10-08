class CreateSceneImagesJob < ApplicationJob
  queue_as :default

  def perform(*args)
    scene = args.first
    puts "######## CreateSceneImagesJob #{scene} ########"
    LeonardoClient.generate_scene_images(scene)
  end
end
