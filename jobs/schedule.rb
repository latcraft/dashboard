
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

SCHEDULER.every '1m', :first_in => 0 do |job|
  current_time = Time.now.in_time_zone('Europe/Riga')
  schedule = JSON.parse(open(global_config['schedule_data_file']) { |f| f.read })
  current_month = "#{Date::MONTHNAMES[(Date.today + 15).month]} #{(Date.today + 15).year}"
  next_event = schedule.select { |event| event['month'] == current_month }.first  
  if !next_event.nil?
    sessions = next_event['schedule']
    sessions.each do |session|
      if !session['img'].nil? and !session['img'].empty? and !session['img'].start_with?('http')
        session['img'] = "http://latcraft.lv/" + session['img']
      end
    end
    send_event('schedule', sessions: sessions)
  end
end

