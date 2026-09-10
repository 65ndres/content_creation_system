class ScenesController < ActionController::Base
  def rewrite_prompt
    scene = Scene.find(params[:id])
    if scene.story_id.to_s != params[:story_id].to_s
      return redirect_to stories_path
    end

    LeonardoClient.rewrite_blocked_scene_prompts(
      scene,
      instruction: params[:instruction],
      force: true
    )
    redirect_to story_path(scene.story_id)
  end
end
