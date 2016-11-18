
require_relative '../jobs/devternity.rb'

def time(h, m) 
  return Time.now.in_time_zone('Europe/Riga').change({hour: h, min: m})
end

tests = {
  time(12, 55) => '13:40',
  time(12, 56) => '13:40',
  time(12, 57) => '13:40',
  time(12, 58) => '13:40',
  time(12, 59) => '13:40',
}

describe "schedule" do 

  before(:each) do
    @global_config = { 'devternity_data_file' => 'http://devternity.com/js/event.js' }
    @now = Time.now
  end

  tests.each do |actualTime, expectedTime|
    it "should return events starting on #{expectedTime} when the actual time is #{actualTime.strftime '%H:%M'}" do
      allow(Time).to receive(:now).and_return(actualTime)
      Devternity.send_schedule_updates @global_config, nil do |eventName, eventData| 
        expect(eventData[:session][:time]).to eql(expectedTime) 
      end
    end
  end

end


