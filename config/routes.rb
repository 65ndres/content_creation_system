require "sidekiq/web"

Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  if Rails.env.development?
    mount Sidekiq::Web => "/sidekiq"
  elsif ENV["SIDEKIQ_WEB_USER"].present? && ENV["SIDEKIQ_WEB_PASSWORD"].present?
    sidekiq_app = Rack::Builder.new do
      use Rack::Auth::Basic, "Sidekiq" do |username, password|
        ActiveSupport::SecurityUtils.secure_compare(username, ENV["SIDEKIQ_WEB_USER"]) &
          ActiveSupport::SecurityUtils.secure_compare(password, ENV["SIDEKIQ_WEB_PASSWORD"])
      end
      run Sidekiq::Web
    end
    mount sidekiq_app => "/sidekiq"
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  root "dashboard#index"

  get "stories", to: "dashboard#index", as: :stories
  get "stories/new", to: "dashboard#new", as: :new_story
  post "stories", to: "dashboard#create", as: :create_story
  get "stories/:id", to: "dashboard#show", as: :story
  post "stories/:story_id/scenes/:id/rewrite_prompt", to: "scenes#rewrite_prompt", as: :rewrite_story_scene

  get "sources/new", to: "dashboard#new_source", as: :new_source
  post "sources/generate", to: "sources#generate", as: :generate_source
  resources :sources, only: [ :create ]

  get "story_types/new", to: "dashboard#new_story_type", as: :new_story_type
  post "story_types/generate", to: "story_types#generate", as: :generate_story_type
  resources :story_types, only: [ :create ]
end
