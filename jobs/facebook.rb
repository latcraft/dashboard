
require 'yaml'
require 'koala'

###########################################################################
# Load configuration parameters.
###########################################################################

global_config = YAML.load_file('./config/integrations.yml') || {}
fb_page = URI::encode(global_config['facebook_page'] || "DevTernity")
$graph = Koala::Facebook::API.new(global_config['facebook_access_token'], global_config['facebook_app_secret'])

def page_info(page_name)
  info = $graph.get_object(
    page_name,
    { fields: ['about', 'fan_count', 'new_like_count', 'rating_count', 'country_page_likes', 'talking_about_count', 'were_here_count', 'checkins', 'cover', 'ratings', 'published_posts'] },
    { :use_ssl => true }
  )
  {
    likes: info['fan_count'],
    checkins: info['checkins'],
    were_here: info['were_here_count'],
    talking_about: info['talking_about_count']
  }
end

###########################################################################
# Job's schedules.
###########################################################################

SCHEDULER.every '1m', :first_in => 0 do |job|
  data = page_info(fb_page)
  send_event('facebook_likes', current: data[:likes])
  send_event('facebook_checkins', current: data[:checkins])
  send_event('facebook_were_here_count', current: data[:were_here])
  send_event('facebook_talking_about_count', current: data[:talking_about])
end

