require 'chatgpt/client'
Rails.application.config.after_initialize do
    ChatGPTClient = ChatGPT::Client.new(ENV['CHATGPT_KEY'])
end