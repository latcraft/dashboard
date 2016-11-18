
require_relative '../jobs/devternity.rb'

describe "schedule" do

  before(:each) do
    @global_config = { 'devternity_data_file' => 'http://devternity.com/js/event.js' }
    @events = {}
  end

  it "should return" do
    allow(Time).to receive(:now).and_return(2.hours.ago)
    Devternity.send_schedule_updates @global_config, nil do |eventName, eventData| 
      @events[eventName] = eventData
    end
    puts "#{@events}"
    # TODO: implement asserts
  end
end


