
require 'active_support/core_ext/enumerable'
require 'active_support/time'
require 'json'
require 'yaml'
require 'date'
require 'firebase'

$firebase_json = File.open('./config/firebase-voting.json') { |file| file.read }
$firebase_config = JSON.parse($firebase_json)
$base_url = "https://#{$firebase_config['project_id']}.firebaseio.com/"
$firebase_client = Firebase::Client.new($base_url, $firebase_json)

def time_rand(
  from = Time.now.in_time_zone('Europe/Riga').beginning_of_day, 
  to   = Time.now.in_time_zone('Europe/Riga').end_of_day
)
  Time.at(from + rand * (to.to_f - from.to_f))
end

2000.times do |i|
  $firebase_client.push("votes", {
    :device => ['test_1', 'test_2', 'test_3', 'test_4'].sample,
    :color => ['green', 'green', 'green', 'green', 'red', 'yellow'].sample,
    :created => time_rand().to_i
  })
end
