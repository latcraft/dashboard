
require_relative '../jobs/devternity.rb'

def time(h, m) 
  return Time.now.in_time_zone('Europe/Riga').change({hour: h, min: m})
end

tests = {
  time(5, 00) => '8:00',
  time(7, 00) => '8:00',
  time(8, 00) => '8:00',
  time(8, 10) => '8:00',
  time(8, 15) => '9:00',
  time(8, 45) => '9:00',
  time(9, 00) => '9:00',
  time(9, 05) => '9:15',
  time(9, 15) => '9:15',
  time(9, 30) => '10:10',
  time(9, 45) => '10:10',
  time(10, 10) => '10:10',
  time(10, 15) => '10:30',
  time(10, 20) => '10:30',
  time(10, 30) => '10:30',
  time(10, 35) => '10:30',
  time(10, 45) => '11:20',
  time(10, 55) => '11:20',
  time(11, 10) => '11:20',
  time(11, 20) => '11:20',
  time(11, 25) => '11:40',
  time(11, 35) => '11:40',
  time(11, 40) => '11:40',
  time(11, 45) => '11:40',
  time(11, 55) => '12:30',
  time(12, 25) => '12:30',
  time(12, 30) => '12:30',
  time(12, 45) => '13:40',
  time(13, 40) => '13:40',
  time(13, 55) => '14:30',
  time(14, 30) => '14:30',
  time(14, 35) => '14:50',
  time(14, 50) => '14:50',
  time(15, 00) => '14:50',
  time(15, 05) => '15:40',
  time(15, 40) => '15:40',
  time(15, 45) => '16:00',
  time(16, 00) => '16:00',
  time(16, 10) => '16:00',
  time(16, 15) => '16:50',
  time(16, 25) => '16:50',
  time(16, 50) => '16:50',
  time(16, 55) => '17:10',
  time(17, 10) => '17:10',
  time(17, 25) => '18:00',
  time(18, 00) => '18:00',
  time(18, 05) => '18:20',
  time(18, 20) => '18:20',
  time(18, 35) => '19:10',
  time(19, 10) => '19:10',
  time(19, 20) => '19:30',
  time(19, 30) => '19:30',
  time(20, 30) => '19:30',
  time(21, 30) => '19:30',
  time(22, 30) => '19:30',
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


