# Modified from https://github.com/google/google-api-ruby-client-samples/blob/1480725b07e7048bc5dc7048606a016c5a8378a7/service_account/analytics.rb
# Inspired by https://gist.github.com/3166610
require 'active_record'
require 'active_support/time'
require 'date'
require 'google/api_client'
require 'sqlite3'
require 'yaml'

API_VERSION = 'v3'
CACHED_API_FILE = "#{ENV["TMPDIR"] || "/tmp/"}.ga-analytics-#{API_VERSION}.cache"

## Read app credentials from a file
global_config = YAML.load_file('/etc/latcraft.yml')
global_opts = global_config['ga'] || {}

class GaQueryClient
  attr_reader :profileID
  attr_reader :client

 def initialize(opts)
    application_name = opts['application_name']
    application_version = opts['application_version']
    service_account_email = opts['service_account_email']  # Email of service account
    key_file = opts['key_file']                            # File containing your private key
    key_secret = opts['key_secret']                        # Password to unlock private key
    @profileID = opts['profile_id'].to_s                   # Analytics profile ID.

    @client = Google::APIClient.new(
      :application_name => application_name,
      :client_id => service_account_email,
      :application_version => application_version)

    ## Load our credentials for the service account
    key = Google::APIClient::KeyUtils.load_from_pkcs12(key_file, key_secret)

    @client.authorization = Signet::OAuth2::Client.new(
      :token_credential_uri => 'https://accounts.google.com/o/oauth2/token',
      :audience => 'https://accounts.google.com/o/oauth2/token',
      :scope => 'https://www.googleapis.com/auth/analytics.readonly',
      :issuer => service_account_email,
      :signing_key => key)

    @client.retries = 5
    ## Request a token for our service account
    @client.authorization.fetch_access_token!

    @analytics = nil
    ## Load cached discovered API, if it exists. This prevents retrieving the
    ## discovery document on every run, saving a round-trip to the discovery service.
    if File.exists? CACHED_API_FILE
      File.open(CACHED_API_FILE) do |file|
        @analytics = Marshal.load(file)
      end
    else
      @analytics = @client.discovered_api('analytics', API_VERSION)
      File.open(CACHED_API_FILE, 'w') do |file|
        Marshal.dump(@analytics, file)
      end
    end
  end

  ## Query Parameters Summary https://developers.google.com/analytics/devguides/reporting/core/v3/reference#q_summary
  ## Funcation to query google for a set of analytics attributes
 def query(start_date, end_date, dimension, metric, sort)
    parameters = {
      'ids' => "ga:" + @profileID,
      'start-date' => start_date,
      'end-date' => end_date,
      'dimensions' => dimension,
      'metrics' => metric,
      'sort' => sort
    }

    result = @client.execute(:api_method => @analytics.data.ga.get, :parameters => parameters)
    if result.status == 200 then
      # Everything is OK
    else
      # Error, like HTTP 403, permission denied
      # Rewrap in Google ClientError
      raise Google::APIClient::ClientError.new "GA error #{result.data.error['code']}: #{result.data.error['message']}"
    end

    return result
  end
end

class GaSQLite
  @@db_con = nil

  def initialize(global_config)
    db_path = global_config['ga_db_path'] || '/var/lib/sqlite/ga-metrics.db'
    if @@db_con.nil? then
      @@db_con = SQLite3::Database.new db_path
      ActiveRecord::Base.establish_connection(
        :adapter => 'sqlite3',
        :database => db_path
      )
    end
  end

  def execute(sql)
    @@db_con.execute(sql)
  end
end

class GaSQLiteMetrics
  @@types = {
    "STRING"  => "TEXT",
    "INTEGER" => "INTEGER",
    "PERCENT" => "INTEGER",
    "TIME"    => "NUMBER(3,2)",
  }

  def initialize(db, name)
    @db = db
    @name = name
  end

  def create_table!(data)
    columns = ["ga_period TEXT"] + data.column_headers.map{|c| "#{_column(c.name)} #{@@types[c.dataType] || 'TEXT'}"}
    index_columns = ["ga_period"] + data.column_headers.select{|h| h.columnType == "DIMENSION"}.map{|c| _column(c.name)}

    sqls = [
      "CREATE TABLE IF NOT EXISTS #{@name}(#{columns.join(", ")});",
      "CREATE UNIQUE INDEX IF NOT EXISTS #{@name}_DIMENSION ON #{@name} (#{index_columns.join(", ")});",
    ]

    sqls.each { |sql| @db.execute(sql) }
  end

  def push_data!(period, data)
    _Q = active_record
    _Q.reset_column_information
    _Q.where(ga_period: period).delete_all

    data.rows.map {|row|
      q = _Q.new
      q.attributes = Hash[data.column_headers.map {|c| _column(c.name)}.zip(row)]
      q.ga_period = period
      q.save
    }
  end

  def active_record
    # Memory leak?
    klazz = Class.new(ActiveRecord::Base) do  
      self.table_name = @name
    end
    klazz.table_name = @name
    klazz
  end

  def _column(name)
    name.gsub("ga:", "")
  end

end

@db = GaSQLite.new(global_opts)
@client = GaQueryClient.new(global_opts)

## Dimensions and Metrics Reference: https://developers.google.com/analytics/devguides/reporting/core/dimsmets
## A single dimension data request to be retrieved from the API is limited to a maximum of 7 dimensions
## A single metrics data request to be retrieved from the API is limited to a maximum of 10 metrics
ga_attributes_yml = global_opts['ga_attributes_yml']

## Set of dimensions and metrics to query in a file and iterate
attributes = YAML.load_file(ga_attributes_yml)

# will query for one single date, yesterday
date_day = DateTime.now.yesterday.strftime("%Y-%m-%d")

attributes.each_key { |name|
  gadata = @client.query(date_day, date_day, attributes[name]['dimension'], attributes[name]['metric'], attributes[name]['sort'])
  sql_data = GaSQLiteMetrics.new(@db, name)
  sql_data.create_table!    gadata.data
  sql_data.push_data!       "date_#{date_day}", gadata.data
}

