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

  def generate_video
    scene = find_story_scene
    return redirect_to stories_path unless scene

    scene.apply_prompt_text!(params[:prompt])
    scene.save if scene.changed?
    scene.enqueue_leonardo_generation!
    redirect_to story_path(scene.story_id)
  end

  def regenerate_video
    scene = find_story_scene
    return redirect_to stories_path unless scene

    scene.regenerate_leonardo_generation!(prompt: params[:prompt])
    redirect_to story_path(scene.story_id)
  end

  def regenerate_audio
    scene = find_story_scene
    return redirect_to stories_path unless scene

    scene.regenerate_audio!(text: params[:text])
    redirect_to story_path(scene.story_id)
  end

  private

  def find_story_scene
    scene = Scene.find(params[:id])
    return if scene.story_id.to_s != params[:story_id].to_s

    scene
  end
end
