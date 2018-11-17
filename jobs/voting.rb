# encoding: utf-8

require 'active_support/core_ext/enumerable'
require 'json'
require 'yaml'
require 'date'
require 'firebase'

###########################################################################
# Load configuration parameters.
###########################################################################

$global_config = YAML.load_file('./config/integrations.yml')
$firebase_json = File.open($global_config['firebase_voting_config']).read
$firebase_config = JSON.parse($firebase_json)
$base_url = "https://#{$firebase_config['project_id']}.firebaseio.com/"
$firebase_client = Firebase::Client.new($base_url, $firebase_json)

###########################################################################
# Job's schedules.
###########################################################################

SCHEDULER.every '1m', :first_in => 0 do |job| 
  response = $firebase_client.get("votes", { :color => "green" })
  # response = $firebase_client.push("votes", {
  #   :device => 'test_1',
  #   :color => 'green',
  #   :created => Firebase::ServerValue::TIMESTAMP
  # })
  send_event('votes', { current: response.body.length })
end
