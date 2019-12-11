
require 'dashing'
require 'yaml'
require 'honeycomb-beeline'

$global_config = YAML.load_file('./config/integrations.yml') || {}

Honeycomb.configure do |config|
  config.write_key = $global_config['honeycomb_key'] 
  config.dataset = $global_config['honeycomb_dataset'] || 'devternity'
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

use Honeycomb::Sinatra::Middleware, client: Honeycomb.client

run Sinatra::Application
