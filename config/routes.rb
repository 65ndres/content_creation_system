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

  # Defines the root path route ("/")
  # root "posts#index"
end
