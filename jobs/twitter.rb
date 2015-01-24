
require 'twitter'
require 'active_support/time'
require 'yaml'
require 'sqlite3'
require 'active_record'


###########################################################################
# Load configuration parameters.
###########################################################################

global_config = YAML.load_file('/etc/latcraft.yml')

search_query = URI::encode(global_config['twitter_query'] || "#latcraft")
db_path = global_config['twitter_db_path'] || '/var/lib/sqlite/latcraft.db'


###########################################################################
# Configure Twitter client.
###########################################################################

twitter = Twitter::REST::Client.new do |config|
  config.consumer_key = global_config['twitter_consumer_key']
  config.consumer_secret = global_config['twitter_consumer_secret']
  config.access_token = global_config['twitter_access_token']
  config.access_token_secret = global_config['twitter_access_token_secret']
end


###########################################################################
# Create database and configure connectivity.
###########################################################################

db = SQLite3::Database.new db_path

[
  'CREATE TABLE IF NOT EXISTS TWEETS(ID TEXT, CONTENT TEXT, AVATAR TEXT, NAME TEXT, CREATED_AT TEXT);',
  'CREATE UNIQUE INDEX IF NOT EXISTS TWEET_ID ON TWEETS (ID);',
  'CREATE INDEX IF NOT EXISTS TWEET_DATE ON TWEETS (CREATED_AT);',
  'CREATE INDEX IF NOT EXISTS TWEET_DATE ON TWEETS (NAME);',
  'CREATE INDEX IF NOT EXISTS TWEET_DATE ON TWEETS (TEXT);',
].each { |sql| db.execute(sql) }

ActiveRecord::Base.establish_connection(
  :adapter => 'sqlite3',
  :database => db_path
)

class Tweet < ActiveRecord::Base
end


###########################################################################
# Job's body.
###########################################################################

SCHEDULER.every '1m', :first_in => 0 do |job|
  begin

    # Perform Twitter search for most recent tweets.
    tweets = twitter.search("#{search_query}", { :result_type => 'recent', :count => 100 })

    # Save all tweets in database for later query.
    if tweets
      tweets.each do |tweet|
        if !Tweet.exists?(id: tweet.id)
          t = Tweet.new
          t.ID = tweet.id
          t.CREATED_AT = tweet.created_at.in_time_zone('Europe/Riga').iso8601
          t.CONTENT = tweet.text
          t.AVATAR = "#{tweet.user.profile_image_url_https}" 
          t.NAME = tweet.user.name
          t.save
        end
      end
    end

    # Send most recent 18 tweets (excluding retweets) to dashboard.
    if tweets
      tweets = tweets.select { |tweet| !tweet.text.start_with?('RT') }.take(18).map do |tweet|
        { 
          name: tweet.user.name, 
          avatar: "#{tweet.user.profile_image_url_https}",
          time: tweet.created_at.in_time_zone('Europe/Riga').strftime("%m-%d %H:%M:%S"), 
          body: tweet.text, 
        }
      end
      send_event('twitter_mentions', comments: tweets.sort { |a, b| b[:time] <=> a[:time] })
    end

    # Select number of tweets posted per hour for last 10 hours and send it to dashboard.
    activity = []
    i = 10
    db.execute( "select count(*), strftime('%Y-%m-%d %H:00', created_at) from tweets group by 2 order by 2 desc limit 10;" ) do |row|
      activity << { 
        x: i, 
        y: row[0] 
      }
      i -= 1
    end
    activity = activity.sort { |a, b| a[:x] <=> b[:x] }
    if !activity.empty?
      send_event('twitter_activity', { graphtype: 'bar', points: activity })
    end

    # Select top users that posted tweets within last 3 hours and send it to dashboard.
    top_users = []
    query_time = Time.now.in_time_zone('Europe/Riga').advance(:hours => -12).iso8601
    db.execute( "select count(*), name, avatar from tweets where datetime(created_at) > datetime(?) and content not like 'RT%' group by 2, 3 order by 1, 2 desc;", [query_time] ) do |row|
      top_users << { 
        name: row[1], 
        avatar: row[2],
        tweet_count: row[0] 
      }
    end
    if !top_users.empty?
      send_event('twitter_top_users', { users: top_users })
    end

  rescue Twitter::Error
    puts "\e[33mFor the twitter widget to work, you need to put in your twitter API keys in /etc/latcraft.yml file.\e[0m"
  end
end




