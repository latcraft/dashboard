# encoding: utf-8

require 'active_support/core_ext/enumerable'
require 'json'
require 'yaml'
require 'date'
require 'firebase'

###########################################################################
# Load configuration parameters.
###########################################################################

$firebase_json = File.open('./config/firebase-sales.json') { |file| file.read }
$firebase_config = JSON.parse($firebase_json)
$base_url = "https://#{$firebase_config['project_id']}.firebaseio.com/"

DT2018_PRODUCTS = [ 'DT_RIX_18' ]
DT2018_DAY1_KEYNOTE = 'Main Day Pass'
DT2018_ERROR_TICKETS_EVENT = 'Error: Tickets data error'

WORKSHOP_CAPACITIES = {
  "KC A" => 36,
  "KC B" => 45,
  "KC C" => 45,
  "KC D" => 44,
  "R 78" => 50,
  "R 75" => 16
}

WORKSHOP_CAPACITY = WORKSHOP_CAPACITIES.map { |k,v| v }.sum
MAIN_DAY_CAPACITY = 600

###########################################################################
# Data logic.
###########################################################################

class DevternityFirebaseStats

  attr_reader :client

  def initialize(opts, auth_token)
    base_url = "https://#{opts['project_id']}.firebaseio.com/"
    @client = Firebase::Client.new(base_url, auth_token)
  end

  def call(job)

    capacities = WORKSHOP_CAPACITIES.merge({ "Main Hall" => MAIN_DAY_CAPACITY })

    sales = counts()

    event_stats = sales[:tickets]
      .sort_by { |name, count| -count }
      .map { |name, count| { label: name + remaining(capacities, count), value: count } }

    day1Tickets = sales[:tickets][DT2018_DAY1_KEYNOTE]

    send_event('tickets', { title: "#{sales[:total]} tickets purchased", moreinfo: "Total #{sales[:total]}", items: event_stats })
    send_event('keynotes', { max: MAIN_DAY_CAPACITY, moreinfo: "#{day1Tickets}/#{MAIN_DAY_CAPACITY}", value: day1Tickets })
    send_event('workshops', { max: WORKSHOP_CAPACITY, moreinfo: "#{sales[:total] - day1Tickets}/#{WORKSHOP_CAPACITY}", value: sales[:total] - day1Tickets })

  end

  private

  def remaining(capacities, count)
    max = capacities.max_by{ |k,v| v }
    capacities.delete(max.first)
    " (#{max.last - count} out of #{max.last} left in #{max.first})"
  end

  def counts(data = clean_applications())

    tickets = Hash.new(0)

    counter = -> names {
      counted = Hash.new(0)
      names.each { |h| counted[h] += 1 }
      counted = Hash[counted.map { |k, v| [k, v] }]
      counted
    }

    merger = -> totals, adds {
      adds.each { |key, value| totals[key] += value }
      totals
    }

    data.each do |id, application|
      order_tickets = application[:tickets].flatten
      ticket_counters = counter.call(order_tickets)
      tickets = merger.call(tickets, ticket_counters)
      totals = ticket_counters.values.inject(0, :+)  
    end

    { tickets: tickets, total: tickets.values.inject(0, :+) }

  end

  def clean_applications(data = raw_applications())
    if !data.nil? && !data.empty?
      dt2018_data = data.select { |id, application| DT2018_PRODUCTS.include?(application['product']) }
      return dt2018_data.map { |id, application|
        tickets = application['tickets'] || [DT2018_ERROR_TICKETS_EVENT]
        tickets = [ tickets ] unless tickets.is_a? Array
        tickets = tickets.map { |ticket| ticket['event'] || DT2018_ERROR_TICKETS_EVENT }
        [ id, { tickets: tickets } ]
      }.to_h
    else 
      return { }
    end
  end

  def raw_applications
    response = @client.get('applications')
    raise "DT error #{response.code} (#{response.body})" unless response.success?
    response.body
  end

end

###########################################################################
# Job's schedules.
###########################################################################

stats = DevternityFirebaseStats.new($firebase_config, $firebase_json)

SCHEDULER.every '15m', :first_in => 0 do |job| 
  stats.call(job)
end
