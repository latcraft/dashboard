
require 'twitter'
require 'active_support/time'
require 'yaml'
require 'sqlite3'
require 'active_record'
require 'htmlentities'


###########################################################################
# Load configuration parameters.
###########################################################################

global_config = YAML.load_file('./config/latcraft.yml') || {}

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
  'CREATE TABLE IF NOT EXISTS MEDIA(ID TEXT, SHORT_URI TEXT, URI TEXT, CREATED_AT TEXT);',
  'CREATE UNIQUE INDEX IF NOT EXISTS MEDIA_ID ON MEDIA (ID);',
  'CREATE INDEX IF NOT EXISTS MEDIA_DATE ON MEDIA (CREATED_AT);',
  # 'CREATE TABLE IF NOT EXISTS FOLLOWERS(ID TEXT, SHORT TEXT, AVATAR TEXT, NAME TEXT, CREATED_AT TEXT);',
].each { |sql| db.execute(sql) }

class Tweet < ActiveRecord::Base
end

class Media < ActiveRecord::Base
end

# class Follower < ActiveRecord::Base
# end

Tweet.establish_connection(
  :adapter => 'sqlite3',
  :database => db_path
)

Media.establish_connection(
  :adapter => 'sqlite3',
  :database => db_path
)

# Follower.establish_connection(
#   :adapter => 'sqlite3',
#   :database => db_path
# )


###########################################################################
# Utilities.
###########################################################################

def get_tweet_text(tweet)
  final_text = tweet.text
  if tweet.media?
    tweet.media.each { |media| 
      final_text = final_text.sub(media.uri, "<img src=\"#{media.media_uri}\" />")
    }
  end
  if tweet.uris?
    tweet.uris.each { |uri| 
      final_text = final_text.sub(uri.uri, "#{uri.expanded_uri}")
    }
  end
  return final_text
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
          t            = Tweet.new
          t.ID         = tweet.id
          t.CREATED_AT = tweet.created_at.in_time_zone('Europe/Riga').iso8601
          t.CONTENT    = tweet.text
          t.AVATAR     = "#{tweet.user.profile_image_url_https}" 
          t.NAME       = tweet.user.name
          t.save
          if tweet.media? 
            tweet.media.each_with_index do |media, index|
              media_id       = "#{tweet.id}_#{index}"
              if !Media.exists?(id: media_id)
                m             = Media.new
                m.ID          = media_id
                m.CREATED_AT  = tweet.created_at.in_time_zone('Europe/Riga').iso8601
                m.SHORT_URI   = media.uri
                m.URI         = media.media_uri
                m.save
              end
            end
          end
        end
      end
    end

    # Send most recent 18 tweets (excluding retweets) to dashboard.
    if tweets
      tweets = tweets.select { |tweet| !tweet.text.start_with?('RT') }.take(18).map do |tweet|
        { 
          name:      tweet.user.name, 
          avatar:    "#{tweet.user.profile_image_url_https}",
          time:      tweet.created_at.in_time_zone('Europe/Riga').strftime("%m-%d %H:%M:%S"), 
          body:      get_tweet_text(tweet), 
          media:     tweet.media.map { |media| media.media_uri },
          has_media: tweet.media?,
        }
      end
      send_event('twitter_mentions', tweets: tweets.sort { |a, b| b[:time] <=> a[:time] })
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
    db.execute( "select count(*), name, avatar from tweets where datetime(created_at) > datetime(?) and content not like 'RT%' group by 2, 3 order by 1 desc, 2 asc;", [query_time] ) do |row|
      top_users << { 
        name: row[1], 
        avatar: row[2],
        tweet_count: row[0] 
      }
    end
    exclude_users = global_config['twitter_exclude_heroes'] || []
    top_users = top_users.select { |user| !(exclude_users.include? user['name']) } 
    if !top_users.empty?
      send_event('twitter_top_users', { users: top_users.take(6) })
    end

  rescue Twitter::Error
    puts "\e[33mFor the twitter widget to work, you need to put in your twitter API keys in ./config/latcraft.yml file.\e[0m"
  end
end


SCHEDULER.every '1h', :first_in => 0 do |job|

  # TODO: extract all twitter followers and add/remove

end

