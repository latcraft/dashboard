# 
# require 'json'
# require 'net/http'
# require 'open-uri'
# require 'active_support/time'
# require 'uri'
# require 'yaml'
# require 'date'
# 
# ###########################################################################
# # Load configuration parameters.
# ###########################################################################
# 
# global_config = YAML.load_file('./config/latcraft.yml')
# 
# 
# ###########################################################################
# # Job's body.
# ###########################################################################
# 
# def to_min(time_code)
#   return (time_code / 100) * 60 + time_code % 100
# end
# 
# def type2image(type, title)  
#   base_path = '/assets/events/'
#   if title.include? "Lunch"
#     return base_path + 'dash_lunch.png'
#   elsif title.include? "Opening"
#     return base_path + 'dash_opening.png'
#   elsif title.include? "Final"
#     return base_path + 'dash_finish.png'
#   elsif title.include? "Beer"
#     return base_path + 'dash_party.png'
#   elsif type == "start"
#     return base_path + 'dash_start.png'
#   elsif type == "break"
#     return base_path + 'dash_break.png'
#   end
#   return ''
# end
# 
# def type2room(type, title)  
#   if title.include? "Lunch"
#     return 'CAFE'
#   elsif title.include? "Beer"
#     return 'OUTSIDE'
#   elsif title.include? "Opening"
#     return 'ROOM '
#   elsif title.include? "Final"
#     return 'ROOM '
#   elsif type == "start"
#     return 'HALL'
#   elsif type == "break"
#     return 'HALL'
#   end
#   return 'ROOM '
# end
# 
# SCHEDULER.every '1m', :first_in => 0 do |job|
#   current_time = Time.now.in_time_zone('Europe/Riga')
#   current_min  = current_time.hour * 60 + current_time.min
#   schedule     = JSON.parse(open(global_config['devternity_data_file']) { |f| f.read }).first['schedule']
#   time_slots   = schedule.map do |time_slot|
#     { 
#       :time      => time_slot['time'], 
#       :time_code => time_slot['time'].split(':').join('').to_i, 
#       :name      => time_slot['name'],
#       :title     => time_slot['title'],
#       :type      => time_slot['type'],
#       :room_name => type2room(time_slot['type'], time_slot['title']),
#       :img       => time_slot['img'].nil? ? type2image(time_slot['type'], time_slot['title']) : 'http://devternity.com/' + time_slot['img']
#     }
#   end
#   valid_slots = time_slots.select { |time_slot| to_min(time_slot[:time_code]) > current_min + 15 }  
#   current_slots = valid_slots.select { |slot| slot[:time_code] == valid_slots.first[:time_code] }
#   if current_slots && current_slots.size > 0
#     track1 = current_slots[0]
#     track2 = current_slots.size > 1 ? current_slots[1].clone : current_slots[0].clone
#     track3 = current_slots.size > 2 ? current_slots[2].clone : current_slots[0].clone
#     if track1[:room_name].start_with? 'ROOM '
#       track1[:room_name] += '1'
#     end
#     if track2[:room_name].start_with? 'ROOM '
#       track2[:room_name] += '2'
#     end
#     if track3[:room_name].start_with? 'ROOM '
#       track3[:room_name] += '3'
#     end
#     send_event('track1', session: track1)
#     send_event('track2', session: track2)
#     send_event('track3', session: track3)
#   end
# end
# 
# 