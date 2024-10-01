class CreateSceneImagesMotionJob < ApplicationJob
  queue_as :default

  def perform(*args)
    scene = args.first
    puts "########  CreateSceneImagesMotionJob #{scene} ########"
    # VideoEditorClient.create_scene_video(scene)
    LeonardoClient.create_scene_motion_images(scene)
  end
end