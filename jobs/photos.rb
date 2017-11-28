
require 'json'
require 'net/http'
require 'open-uri'
require 'active_support/time'
require 'uri'
require 'yaml'
require 'date'

###########################################################################
# Job's body.
###########################################################################

r_location = Random.new
r_sample = Random.new

SCHEDULER.every '10s', :first_in => 0 do |job|
  global_config = YAML.load_file('./config/latcraft.yml')
  send_event('photo' + (1 + r_location.rand(6)).to_s, image: global_config['photos'].sample(random: r_sample))
end

