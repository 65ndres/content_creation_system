class CheckSceneStartFrameStatusJob < ApplicationJob
  queue_as :default

  def perform(*args)
    scene = args.first
    Rails.logger.info("CheckSceneStartFrameStatusJob scene=#{scene.id}")
    LeonardoClient.check_scene_start_frame_status(scene)
  end
end
