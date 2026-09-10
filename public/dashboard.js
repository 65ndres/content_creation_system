(function () {
  const csrf = document.querySelector('meta[name="csrf-token"]')?.content || "";

  function setStatus(el, message, isError) {
    if (!el) return;
    el.textContent = message;
    el.classList.toggle("is-error", Boolean(isError));
  }

  async function postJson(url, body) {
    const response = await fetch(url, {
      method: "POST",
      credentials: "same-origin",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        "X-CSRF-Token": csrf
      },
      body: JSON.stringify(body)
    });

    const data = await response.json().catch(() => ({}));
    if (!response.ok) {
      throw new Error(data.error || data.exception || "Request failed");
    }
    return data;
  }

  function initComposer(root) {
    const kind = root.dataset.composer;
    const promptEl = root.querySelector("[data-prompt]");
    const resultEl = root.querySelector("[data-result]");
    const generateBtn = root.querySelector("[data-generate]");
    const saveBtn = root.querySelector("[data-save]");
    const statusEl = root.querySelector("[data-status]");
    const saveStatusEl = root.querySelector("[data-save-status]");

    generateBtn?.addEventListener("click", async () => {
      const prompt = promptEl.value.trim();
      if (!prompt) {
        setStatus(statusEl, "Type something in the box first.", true);
        promptEl.focus();
        return;
      }

      generateBtn.disabled = true;
      setStatus(statusEl, "Sending to ChatGPT… this can take a minute.");

      try {
        const data = await postJson(root.dataset.generateUrl, { prompt });
        resultEl.hidden = false;
        setStatus(saveStatusEl, "");

        if (kind === "source") {
          const textEl = root.querySelector("[data-source-text]");
          textEl.value = data.text || "";
          setStatus(statusEl, "Source drafted. Edit it below if you want, then save.");
          textEl.focus();
        } else {
          root.querySelector("[data-name]").value = data.name || "";
          root.querySelector("[data-story-prompt]").value = data.story_prompt_text || "";
          root.querySelector("[data-scenes-prompt]").value = data.scenes_json_prompts || "";
          setStatus(statusEl, "Story type drafted. Edit it below if you want, then save.");
          root.querySelector("[data-name]").focus();
        }
      } catch (error) {
        setStatus(statusEl, error.message, true);
      } finally {
        generateBtn.disabled = false;
      }
    });

    saveBtn?.addEventListener("click", async () => {
      let body;

      if (kind === "source") {
        const text = root.querySelector("[data-source-text]").value.trim();
        if (!text) {
          setStatus(saveStatusEl, "Source text is empty.", true);
          return;
        }
        body = { text };
      } else {
        const name = root.querySelector("[data-name]").value.trim();
        const storyPrompt = root.querySelector("[data-story-prompt]").value.trim();
        const scenesPrompt = root.querySelector("[data-scenes-prompt]").value.trim();
        if (!name || !storyPrompt || !scenesPrompt) {
          setStatus(saveStatusEl, "Name, story prompt, and scenes prompt are required.", true);
          return;
        }
        body = {
          name,
          story_prompt_text: storyPrompt,
          scenes_json_prompts: scenesPrompt,
          image_width: root.querySelector("[data-image-width]").value,
          image_height: root.querySelector("[data-image-height]").value,
          output_width: root.querySelector("[data-output-width]").value,
          output_height: root.querySelector("[data-output-height]").value,
          scene_text_min_chars: 70,
          scene_text_max_chars: 100
        };
      }

      saveBtn.disabled = true;
      setStatus(saveStatusEl, "Saving…");

      try {
        const data = await postJson(root.dataset.saveUrl, body);
        if (kind === "source") {
          setStatus(saveStatusEl, "Saved as source #" + data.id + ".");
        } else {
          setStatus(saveStatusEl, "Saved as story type #" + data.id + (data.name ? " · " + data.name : "") + ".");
        }
      } catch (error) {
        setStatus(saveStatusEl, error.message, true);
      } finally {
        saveBtn.disabled = false;
      }
    });
  }

  document.querySelectorAll("[data-composer]").forEach(initComposer);
})();
