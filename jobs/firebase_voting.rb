# encoding: utf-8

require 'active_support/core_ext/enumerable'
require 'active_support/time'
require 'json'
require 'yaml'
require 'date'
require 'firebase'

###########################################################################
# Load configuration parameters.
###########################################################################

$firebase_json = File.open('./config/firebase-voting.json') { |file| file.read }
$firebase_config = JSON.parse($firebase_json)
$base_url = "https://#{$firebase_config['project_id']}.firebaseio.com/"
$firebase_client = Firebase::Client.new($base_url, $firebase_json)

def raw_votes(color = "green")
  response = $firebase_client.get("votes", { :color => color })
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

###########################################################################
# Job's schedules.
###########################################################################

SCHEDULER.every '1m', :first_in => 0 do |job| 
  votes = today_votes()
  send_event('votes', { current: votes.length })
end
