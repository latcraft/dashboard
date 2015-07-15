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

class GaData < ActiveRecord::Base
end

class GaSQLiteMetrics
  def initialize(db, name, attributes)
    def _2_columns(elems)
      elems.map {|e| e.gsub("ga:", "")}
    end

    @db = db
    @name = name

    @index_columns = _2_columns(["ga_period"] + attributes['dimension'].split(','))
    @additional_index = []
    @additional_index = _2_columns(["ga_period"] + attributes['db_index'].split(',')) if attributes.has_key?('db_index')

    @columns = _2_columns(attributes['dimension'].split(',') + [attributes['metric']])

    sqls = [
      "CREATE TABLE IF NOT EXISTS #{@name}(#{(["ga_period"] + @columns).map {|c| "#{c} TEXT" }.join(", ")});",
      "CREATE UNIQUE INDEX IF NOT EXISTS #{@name}_UNIQUE ON #{@name} (#{@index_columns.join(", ")});",
    ]

    sqls += [ "CREATE UNIQUE INDEX IF NOT EXISTS #{@name}_UNIQUE_EXTRA ON #{@name} (#{@additional_index.join(", ")});" ] if @additional_index.length > 1

    sqls.each { |sql| @db.execute(sql) }
  end

  def push!(start_date, end_date, data)
    period = "#{start_date}-#{end_date}"
    @db.execute "delete from #{@name} where ga_period='#{period}';"
    data.rows.map {|row| 
      "insert into #{@name}(ga_period, #{data.column_headers.map{|c|c.name.gsub("ga:", "")}.join(", ") })
       values('#{period}', #{row.map{|v| "'#{v}'"}.join(", ")});"
    }
    .each {|sql|
      @db.execute(sql)
    }
  end

  def active_record
    klazz = Class.new(GaData)
    klazz.set_table_name @name
    # Memory leak?
    klazz
  end
end

@db = GaSQLite.new(global_opts)
@client = GaQueryClient.new(global_opts)

## For the moment start and end dates defined here
start_date = DateTime.now.yesterday.strftime("%Y-%m-%d")
end_date = DateTime.now.strftime("%Y-%m-%d")

## Dimensions and Metrics Reference: https://developers.google.com/analytics/devguides/reporting/core/dimsmets
## A single dimension data request to be retrieved from the API is limited to a maximum of 7 dimensions
## A single metrics data request to be retrieved from the API is limited to a maximum of 10 metrics
ga_attributes_yml = global_opts['ga_attributes_yml']

## Set of dimensions and metrics to query in a file and iterate
attributes = YAML.load_file(ga_attributes_yml)

attributes.each_key { |key|
  gadata = @client.query(start_date, end_date, attributes[key]['dimension'], attributes[key]['metric'], attributes[key]['sort'])
  require 'pry'
  binding.pry
  sql_data = GaSQLiteMetrics.new(@db, key, attributes[key])
  sql_data.push! start_date, end_date, gadata.data
  #outfile = File.new("#{key}.txt", "w")
  #outfile.puts gadata.data.column_headers.map { |c| c.name.gsub("ga:","") }.join("\t")
  #gadata.data.rows.each do |r|
  #  outfile.puts r.join("\t")
  #end
}

