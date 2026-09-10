require "test_helper"
require "minitest/mock"

class SourcesControllerTest < ActionDispatch::IntegrationTest
  test "generate returns chatgpt text" do
    ChatGPTClient.stub(:generate_source_text, "drafted source") do
      post generate_source_url, params: { prompt: "write a source" }, as: :json
    end

    assert_response :success
    assert_equal "drafted source", JSON.parse(response.body)["text"]
  end

  test "generate rejects a blank prompt" do
    post generate_source_url, params: { prompt: "  " }, as: :json

    assert_response :unprocessable_entity
    assert_equal "Type something before sending it to ChatGPT.", JSON.parse(response.body)["error"]
  end

  test "create saves a source for the first user" do
    assert_difference("Source.count", 1) do
      post sources_url, params: { text: "saved source text" }, as: :json
    end

    source = Source.order(:id).last
    assert_response :success
    assert_equal User.first.id, source.user_id
    assert_equal "saved source text", source.text
  end
end
