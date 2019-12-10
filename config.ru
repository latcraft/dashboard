
require 'dashing'
require 'honeycomb-beeline'

Honeycomb.configure do |config|
  config.write_key = "cbc71c0b5517257a845b7d0aa71df70c"
  config.dataset = "devternity"
end

configure do
  set :auth_token, 'NOT_PROTECTED'
  set :default_dashboard, 'cycle'
  helpers do
    def protected!
    end
  end
end

map Sinatra::Application.assets_prefix do
  run Sinatra::Application.sprockets
end

run Sinatra::Application