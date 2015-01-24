
require 'json'
require 'net/http'
require 'open-uri'
require 'active_support/time'
require 'uri'

###########################################################################
# Load configuration parameters.
###########################################################################

global_config = YAML.load_file('/etc/latcraft.yml')


###########################################################################
# Job's body.
###########################################################################

SCHEDULER.every '1m', :first_in => 0 do |job|
  current_time = Time.now.in_time_zone('Europe/Riga')
  schedule = JSON.parse(open(global_config['schedule_data_file']) { |f| f.read })
  send_event('schedule', sessions: schedule)
end

