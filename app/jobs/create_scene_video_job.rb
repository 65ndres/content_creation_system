class CreateSceneVideoJob < ApplicationJob
  queue_as :default

  def perform(*args)
    scene = args.first
    puts "######## CreateSceneVideoJob #{scene} ########"
    VideoEditorClient.create_scene_video(scene)
  end
end
