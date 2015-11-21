
require 'yaml'
require 'net/http'
require 'xmlsimple'

###########################################################################
# Load configuration parameters.
###########################################################################
 
global_config = YAML.load_file('./config/latcraft.yml')

woe_id = global_config['yahoo_woe_id'] || "854823" 
format = global_config['yahoo_weather_format'] || 'c'

###########################################################################
# Climate icon mapping to Yahoo weather codes.
###########################################################################
 
climacon_class_to_code = {
  'cloud'            => [26, 44],
  'cloud moon'       => [27, 29],
  'cloud sun'        => [28, 30],
  'drizzle'          => [8, 9],
  'fog'              => [20],
  'hail'             => [17, 35],
  'haze'             => [19, 21, 22],
  'lightning'        => [3, 4, 37, 38, 39, 45, 47],
  'moon'             => [31, 33],
  'rain'             => [11, 12, 40],
  'sleet'            => [6, 10, 18], 
  'snow'             => [5, 7, 13, 14, 15, 16, 41, 42, 43, 46],
  'sun'              => [32, 34],
  'thermometer full' => [36],
  'thermometer low'  => [25],
  'tornado'          => [0, 1, 2],
  'wind'             => [23, 24],  
}

def climacon_class(climacon_class_to_code, weather_code)
  climacon_class_to_code.select{ |k, v| v.include? weather_code.to_i }.to_a.first.first
end 


###########################################################################
# Job's body.
###########################################################################

SCHEDULER.every '5m', :first_in => 0 do |job|
  http = Net::HTTP.new('weather.yahooapis.com')
  response = http.request(Net::HTTP::Get.new("/forecastrss?w=#{woe_id}&u=#{format}"))
  weather_data = XmlSimple.xml_in(response.body, { 'ForceArray' => false })['channel']['item']['condition']
  weather_location = XmlSimple.xml_in(response.body, { 'ForceArray' => false })['channel']['location']
  send_event('weather', { 
    temp:      "#{weather_data['temp']}&deg;#{format.upcase}",
    condition: weather_data['text'],
    title:     "#{weather_location['city']} Weather",
    climacon:  climacon_class(climacon_class_to_code, weather_data['code'])
  })
end
