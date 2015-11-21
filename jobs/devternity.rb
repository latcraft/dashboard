
require 'json'
require 'net/http'
require 'open-uri'
require 'active_support/time'
require 'uri'
require 'yaml'
require 'date'

###########################################################################
# Load configuration parameters.
###########################################################################

global_config = YAML.load_file('./config/latcraft.yml')


###########################################################################
# Job's body.
###########################################################################

def to_min(time_code)
  return (time_code / 100) * 60 + time_code % 100
end

SCHEDULER.every '5s', :first_in => 0 do |job|
  current_time = Time.now.in_time_zone('Europe/Riga')
  current_min  = current_time.hour * 60 + current_time.min
  schedule     = JSON.parse(open(global_config['devternity_data_file']) { |f| f.read }).first['schedule']
  time_slots   = schedule.map do |time_slot|
    { 
      :time      => time_slot['time'], 
      :time_code => time_slot['time'].split(':').join('').to_i, 
      :name      => time_slot['name'],
      :title     => time_slot['title'],
      :type      => time_slot['type'],
      :img       => time_slot['img'].nil? ? '' : 'http://devternity.com/' + time_slot['img']
    }
  end
  valid_slots = time_slots.select { |time_slot| to_min(time_slot[:time_code]) > current_min + 15 }  
  current_slots = valid_slots.select { |slot| slot[:time_code] == valid_slots.first[:time_code] }
  if current_slots && current_slots.size > 0
    track1 = current_slots[0]
    track2 = current_slots.size > 1 ? current_slots[1] : current_slots[0]
    track3 = current_slots.size > 2 ? current_slots[2] : current_slots[0] 
    send_event('track1', session: track1)
    send_event('track2', session: track2)
    send_event('track3', session: track3)
  end
end

