
require 'dashing'

configure do
  set :auth_token, 'NOT_PROTECTED'
  set :default_dashboard, 'event'
  helpers do
    def protected!
    end
  end
end

map Sinatra::Application.assets_prefix do
  run Sinatra::Application.sprockets
end

run Sinatra::Application