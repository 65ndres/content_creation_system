require "test_helper"
require "minitest/mock"

class ElevenlabsClientTest < ActiveSupport::TestCase
  test "create audio file summarizes text when clip is longer than 5 seconds" do
    scene = scenes(:one)
    scene.update_columns(text: "the island was quiet tonight under the stars", audio_too_long: false)
    calls = []

    ChatGPTClient.stub(:summarize_narration, "the island stayed quiet at night") do
      ElevenlabsClient.stub(:generate_audio_bytes, ->(s) {
        calls << s.text
        "ID3long"
      }) do
        ElevenlabsClient.stub(:audio_duration_seconds, ->(_bytes) { calls.size == 1 ? 6.2 : 4.1 }) do
          ElevenlabsClient.stub(:attach_audio, ->(_s, _b) { true }) do
            result = ElevenlabsClient.create_audio_file(scene)
            assert_equal "ID3long", result
          end
        end
      end
    end

    scene.reload
    assert_equal 2, calls.size
    assert_equal "the island was quiet tonight under the stars", calls.first
    assert_equal "the island stayed quiet at night", scene.text
    assert_not scene.audio_too_long?
  end

  test "create audio file marks the scene when three attempts stay too long" do
    scene = scenes(:one)
    scene.update_columns(text: "one two three four five six seven eight", audio_too_long: false)
    summaries = [ "one two three four five", "one two three" ]

    ChatGPTClient.stub(:summarize_narration, ->(_text) { summaries.shift.to_s }) do
      ElevenlabsClient.stub(:generate_audio_bytes, ->(_s) { "ID3long" }) do
        ElevenlabsClient.stub(:audio_duration_seconds, ->(_bytes) { 6.0 }) do
          ElevenlabsClient.stub(:attach_audio, ->(_s, _b) { true }) do
            assert_equal "ID3long", ElevenlabsClient.create_audio_file(scene)
          end
        end
      end
    end

    scene.reload
    assert scene.audio_too_long?
    assert_equal "one two three", scene.text
  end
end
