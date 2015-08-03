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
    authorization_oauth2_json = opts['oauth2_json_authorizationy']
    client_oauth2_json = opts['oauth2_json_client_secret']

    @client = Google::APIClient.new(
      :application_name => application_name,
      :application_version => application_version)

    file_storage = Google::APIClient::FileStorage.new(authorization_oauth2_json)
    if file_storage.authorization.nil?
      client_secrets = Google::APIClient::ClientSecrets.load(client_oauth2_json)
      flow = Google::APIClient::InstalledAppFlow.new(
        :client_id => client_secrets.client_id,
        :client_secret => client_secrets.client_secret,
        :scope => YOUTUBE_SCOPES
      )
      @client.authorization = flow.authorize(file_storage)
    else
      @client.authorization = file_storage.authorization
    end

    @client.retries = 5
    ## Request a token for our service account
    @client.authorization.fetch_access_token!

    @youtube = discovered_api(YOUTUBE_API_SERVICE_NAME, YOUTUBE_API_VERSION)
    @youtube_analytics = discovered_api(YOUTUBE_ANALYTICS_API_SERVICE_NAME, YOUTUBE_ANALYTICS_API_VERSION)
  end

  def query_iterate!(parameters, &block)
    # Retrieve the channel resource for the authenticated user's channel.
    ws_iterate!(
      :api_method => @youtube.channels.list,
      :parameters => { :mine => true, :part => 'id', }) do |channels_response|

        channels_response.items.each do |channel|
          # Call the Analytics API to retrieve a report. For a list of available
          # reports, see:
          # https://developers.google.com/youtube/analytics/v1/channel_reports
          parameters ||= {}
          parameters['ids'] ||= "channel==#{channel.id}"

          ws_iterate!(
            {
              :api_method => @youtube_analytics.reports.query,
              :parameters => parameters
            }) { |yt_stats| block.call(yt_stats) }
        end
      end
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

  def ws_iterate!(request, &block)
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

      block.call(result.data)

      break unless result.next_page_token
      request = result.next_page
    end
  end

end

client = YTClient.new(global_opts)

SCHEDULER.every '2m', :first_in => 0 do |job|
  month_start = DateTime.now.prev_month.at_beginning_of_month.strftime("%Y-%m-%d")
  month_end = DateTime.now.prev_month.at_end_of_month.strftime("%Y-%m-%d")
  
  dimensions='video'
  metrics='estimatedMinutesWatched,views,likes,subscribersGained'
  max_results='10'
  sort='-estimatedMinutesWatched'

  client.query_iterate!({
    'start-date' => month_start,
    'end-date' => month_end,
    'dimension' => dimensions,
    'metrics' => metrics,
    'sort' => sort,
    'start-index' => 1,
    'max-results' => max_results
  }) do |yt_stats|
    send_event('top_ten_videos', { videos: yt_stats })
  end
end

