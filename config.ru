require "sinatra/cyclist"
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

set :routes_to_cycle_through, [:devternity1, :devternity2, :devternity3, :devternity4, :devternity5]

run Sinatra::Application