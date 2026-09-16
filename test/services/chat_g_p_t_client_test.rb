require "test_helper"
require "minitest/mock"

class ChatGPTClientTest < ActiveSupport::TestCase
  test "summarize narration returns a shorter rewrite" do
    ChatGPTClient.stub(:responses_request, "The island stayed quiet.") do
      assert_equal "The island stayed quiet.", ChatGPTClient.summarize_narration(
        "The island was quiet tonight under the stars and nobody spoke."
      )
    end
  end

  test "summarize narration rejects a rewrite that is not shorter" do
    ChatGPTClient.stub(:responses_request, "one two three four five") do
      assert_equal "", ChatGPTClient.summarize_narration("one two three four")
    end
  end
end
