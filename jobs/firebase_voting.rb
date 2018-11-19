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

def group_by_device(votes = today_votes())
  votes.group_by { |id, vote| vote["device"] }
end

def group_by_color(votes = today_votes())
  votes.group_by { |id, vote| vote["color"] }
end

def group_by_time_slot(votes = today_votes(), time_slots = time_slots())
  votes.group_by { |id, vote|
    time_slots.find { |time_slot| 
      vote["created"] >= (time_slot[:end] - 20.minutes).to_f && 
      vote["created"] <= (time_slot[:end] + 20.minutes).to_f
    }
  }
end

def time_slots(schedule = schedule())
  schedule
    .map { |entry| entry['time'] }
    .map { |time| format_time(time) }
    .uniq
    .sort
    .map { |time| Time.parse(time, Time.now.in_time_zone('Europe/Riga')) }
    .each_cons(2)
    .map { |a| { "start": a[0], "end": a[1] } }
end

def format_time(time_str)
  if time_str.length == 4 
    return "0#{time_str}" 
  else              	
    return time_str
  end
end

def schedule
  JSON.parse(open($global_config['devternity_data_file']) { |f| f.read })
    .first['program']
    .find { |e| e['event'] == 'keynotes' }['schedule']
end


###########################################################################
# Job's schedules.
###########################################################################

DEVICE_TRACK_MAPPING = { 
  "track1": [ "test_1", "test_4" ], 
  "track2": [ "test_2" ], 
  "track3": [ "test_3" ]
}

SCHEDULER.every '1m', :first_in => 0 do |job| 

  votes_by_device = group_by_device(today_votes(raw_votes()))
  votes_by_track = { "track1": [], "track2": [], "track3": [] }
  DEVICE_TRACK_MAPPING.each do |track, devices|
    devices.each do |device|
      votes_by_track[track] += votes_by_device[device]
    end
  end  
  votes_by_track.each do |track, track_votes|
    votes_by_track[track] = group_by_time_slot(track_votes)
                              .select { |time_slot, _| !time_slot.nil? }
                              .map { |time_slot, track_votes| 
                                [ time_slot[:start].strftime("%H:%M"), track_votes ] 
                              }.to_h
    votes_by_track[track].each do |time_slot, slot_votes|
      slot_votes_by_color = group_by_color(slot_votes)
      votes_by_track[track][time_slot] = {
        "green": (slot_votes_by_color["green"] || []).length, 
        "red": (slot_votes_by_color["red"] || []).length, 
        "yellow": (slot_votes_by_color["yellow"] || []).length
      }
    end
  end

  send_event('track_votes', { track_votes: votes_by_track })

  today_votes_by_color = group_by_color(today_votes(raw_votes()))
  send_event('votes', { current: (today_votes_by_color["green"] || []).length }) 

end
