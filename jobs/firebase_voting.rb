# encoding: utf-8

require 'active_support/core_ext/enumerable'
require 'active_support/time'
require 'json'
require 'yaml'
require 'date'
require 'time'
require 'firebase'
require 'net/http'
require 'open-uri'
require 'uri'

###########################################################################
# Load configuration parameters.
###########################################################################

$global_config = YAML.load_file('./config/integrations.yml') || {}
$firebase_json = File.open('./config/firebase-voting.json') { |file| file.read }
$firebase_config = JSON.parse($firebase_json)
$base_url = "https://#{$firebase_config['project_id']}.firebaseio.com/"
$firebase_client = Firebase::Client.new($base_url, $firebase_json)

def raw_votes()
  response = $firebase_client.get("votes")
  raise "DT error #{response.code} (#{response.body})" unless response.success?
  response.body
end

def today_votes(votes = raw_votes())
  from = Time.now.in_time_zone('Europe/Riga').beginning_of_day
  to   = Time.now.in_time_zone('Europe/Riga').end_of_day
  votes.select { |id, vote| 
    !vote["created"].nil? && 
     vote["created"] >= from.to_i && 
     vote["created"] <= to.to_i 
  }
end

def group_by_color(votes = today_votes())
  votes.group_by { |id, vote| vote["color"] }
end

###########################################################################
# Job's schedules.
###########################################################################

SCHEDULER.every '1m', :first_in => 0 do |job| 

  today_votes_by_color = group_by_color(today_votes(raw_votes()))
  send_event('greens', { current: (today_votes_by_color["green"] || []).length }) 

end
