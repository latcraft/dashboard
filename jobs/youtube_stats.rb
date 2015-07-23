require 'date'
require 'yaml'
require 'google/api_client'
require 'google/api_client/client_secrets'
require 'google/api_client/auth/file_storage'
require 'google/api_client/auth/installed_app'

require 'active_support/time'

## Read Latcraft global configuration
global_config = YAML.load_file('/etc/latcraft.yml')
## Extract GA stats specific configuration
global_opts = global_config['youtube_analytics'] || {}

# These OAuth 2.0 access scopes allow for read-only access to the authenticated
# user's account for both YouTube Data API resources and YouTube Analytics Data.
YOUTUBE_SCOPES = ['https://www.googleapis.com/auth/youtube.readonly',
  'https://www.googleapis.com/auth/yt-analytics.readonly']
YOUTUBE_API_SERVICE_NAME = 'youtube'
YOUTUBE_API_VERSION = 'v3'
YOUTUBE_ANALYTICS_API_SERVICE_NAME = 'youtubeAnalytics'
YOUTUBE_ANALYTICS_API_VERSION = 'v1'

class YTClient
  attr_reader :client

  def initialize(opts)
    application_name = opts['application_name']
    application_version = opts['application_version']
    service_account_email = opts['service_account_email']  # Email of service account
    key_file = opts['key_file']                            # File containing your private key
    key_secret = opts['key_secret']                        # Password to unlock private key

    @client = Google::APIClient.new(
      :application_name => application_name,
      :client_id => service_account_email,
      :application_version => application_version)

    ## Load our credentials for the service account
    key = Google::APIClient::KeyUtils.load_from_pkcs12(key_file, key_secret)

    @client.authorization = Signet::OAuth2::Client.new(
      :token_credential_uri => 'https://accounts.google.com/o/oauth2/token',
      :audience => 'https://accounts.google.com/o/oauth2/token',
      :scope => YOUTUBE_SCOPES,
      :issuer => service_account_email,
      :signing_key => key)

    @client.retries = 5
    ## Request a token for our service account
    @client.authorization.fetch_access_token!


    @youtube = discovered_api(YOUTUBE_API_SERVICE_NAME, YOUTUBE_API_VERSION)
    @youtube_analytics = discovered_api(YOUTUBE_ANALYTICS_API_SERVICE_NAME, YOUTUBE_ANALYTICS_API_VERSION)
  end

  def query(start_date, end_date, metrics, dimensions, sort, page_size = 10000)
    # Retrieve the channel resource for the authenticated user's channel.
    channels_response = ws!(
      :api_method => @youtube.channels.list,
      :parameters => {
        :mine => true,
        :part => 'id',
      }
    )

    stats = nil

    channels_response.items.each do |channel|
      # Call the Analytics API to retrieve a report. For a list of available
      # reports, see:
      # https://developers.google.com/youtube/analytics/v1/channel_reports
      analytics_response = ws!(
        :api_method => @youtube_analytics.reports.query,
        :parameters => {
          'ids' => "channel==#{channel.id}",
          'start-date' => start_date.strftime("%Y-%m-%d"),
          'end-date' => end_date.strftime("%Y-%m-%d"),
          'metrics' => metrics,
          'dimensions' => dimensions,
          'sort' => sort,
          'start-index' => 1,
          'max-results' => page_size,
        }
      )

      if stats.nil? then
        stats = analytics_response
      else
        # modify in place.
        # Headers are already there. Will append data.rows only
        stats.rows = stats.rows.concat(analytics_response.rows)
      end
    end

    stats
  end


  private
  def discovered_api(service, version)
    api = nil

    cache = "#{ENV["TMPDIR"] || "/tmp/"}/.yt-#{service}-#{version}.cache"
    ## Load cached discovered API, if it exists. This prevents retrieving the
    ## discovery document on every run, saving a round-trip to the discovery service.
    if File.exists? cache
      File.open(cache) do |file|
        api = Marshal.load(file)
      end
    else
      api = @client.discovered_api(service, version)
      File.open(cache, 'w') do |file|
        Marshal.dump(api, file)
      end
    end

    api
  end

  def ws!(request)
    data = nil

    loop do
      result = @client.execute!(request)

      # At some endpoints Google API fails to propogate errors properly.
      # Just to "double-confirm"
      #
      # Instead we need to check result for HTTP status codes ourselves (manually).
      # In our case we've decided to throw exception.
      if result.status == 200 then
        # Everything is OK
      else
        # Error, like HTTP 403, permission denied
        # Rewrap in Google ClientError
        raise Google::APIClient::ClientError.new "YT error #{result.data.error['code']}: #{result.data.error['message']}"
      end

      if data.nil? then
        data = result.data
      else
        # modify in place.
        # Headers are already there. Will append data.rows only
        data.rows = data.rows.concat(result.data.rows)
      end

      break unless result.next_page_token
      request = result.next_page
    end

    data
  end

end

client = YTClient.new(global_opts)

### Test loop
# while true do
#   begin
#     ## No need to store, send to widget instead immediately?
#
#     metrics = 'views,comments,favoritesAdded,favoritesRemoved,likes,dislikes,shares'
#     dimensions = 'video'
#     sort = '-views'
#     start_date = DateTime.now.prev_month.at_beginning_of_month
#     end_date = DateTime.now.prev_month.at_end_of_month
#
#     yt_stats = client.query(start_date, end_date, metrics, dimensions, sort, 200)
#   rescue => e
#     puts "\e[33mFor the YT check /etc/latcraft.yml for the credentials YML.\n\tError: #{e.message}\e[0m"
#     require 'pry'
#     binding.pry
#   end
# end

SCHEDULER.every '1h', :first_in => 0 do |job|
  metrics = 'views,comments,favoritesAdded,favoritesRemoved,likes,dislikes,shares'
  dimensions = 'video'
  sort = '-views'
  start_date = DateTime.now.prev_month.at_beginning_of_month
  end_date = DateTime.now.prev_month.at_end_of_month

  yt_stats = client.query(start_date, end_date, metrics, dimensions, sort, 10)
  send_event('top_ten_videos', { videos: yt_stats })
end

