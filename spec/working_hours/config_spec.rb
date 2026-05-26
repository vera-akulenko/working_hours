# frozen_string_literal: true

require 'spec_helper'

describe WorkingHours::Config do
  describe '#working_hours' do
    let(:config) { WorkingHours::Config.new.working_hours }
    let(:config2) { { mon: { '08:00' => '14:00' } } }
    let(:config3) { { tue: { '10:00' => '16:00' } } }

    it 'has a default config' do
      expect(config).to be_kind_of(Hash)
    end

    it 'is thread safe' do
      expect(WorkingHours::Config.new.working_hours).to eq(config)

      thread = Thread.new do
        WorkingHours::Config.new.working_hours = config2
        expect(WorkingHours::Config.new.working_hours).to eq(config2)
        Thread.stop
        expect(WorkingHours::Config.new.working_hours).to eq(config2)
      end

      expect do
        sleep 0.1 # let the thread begin its execution
      end.not_to change { WorkingHours::Config.new.working_hours }.from(config)

      expect do
        WorkingHours::Config.new.working_hours = config3
      end.to change { WorkingHours::Config.new.working_hours }.from(config).to(config3)

      expect do
        thread.run
        thread.join
      end.not_to change { WorkingHours::Config.new.working_hours }.from(config3)
    end

    it 'is fiber safe' do
      expect(WorkingHours::Config.new.working_hours).to eq(config)

      fiber = Fiber.new do
        WorkingHours::Config.new.working_hours = config2
        expect(WorkingHours::Config.new.working_hours).to eq(config2)
        Fiber.yield
        expect(WorkingHours::Config.new.working_hours).to eq(config2)
      end

      expect do
        fiber.resume
      end.not_to change { WorkingHours::Config.new.working_hours }.from(config)

      expect do
        WorkingHours::Config.new.working_hours = config3
      end.to change { WorkingHours::Config.new.working_hours }.from(config).to(config3)

      expect do
        fiber.resume
      end.not_to change { WorkingHours::Config.new.working_hours }.from(config3)
    end

    it 'is initialized from last known global config' do
      config = WorkingHours::Config.new
      config.working_hours = { mon: { '08:00' => '14:00' } }
      Thread.new do
        expect(config.working_hours).to match mon: { '08:00' => '14:00' }
      end.join
    end

    it 'should have a key for each week day' do
      %i[mon tue wed thu fri].each do |d|
        expect(config[d]).to be_kind_of(Hash)
      end
    end

    it 'should be changeable' do
      time_sheet = { mon: { '08:00' => '14:00' } }
      WorkingHours::Config.new.working_hours = time_sheet
      expect(config).to eq(time_sheet)
    end

    it 'should support multiple timespan per day' do
      time_sheet = { mon: { '08:00' => '12:00', '14:00' => '18:00' } }
      WorkingHours::Config.new.working_hours = time_sheet
      expect(config).to eq(time_sheet)
    end

    it 'recomputes precompiled when modified' do
      time_sheet = { mon: { '08:00' => '14:00' } }
      WorkingHours::Config.new.working_hours = time_sheet
      expect do
        WorkingHours::Config.new.working_hours[:tue] = { '08:00' => '14:00' }
      end.to(change { WorkingHours::Config.new.precompiled[:working_hours][2] })
      expect do
        WorkingHours::Config.new.working_hours[:mon]['08:00'] = '15:00'
      end.to(change { WorkingHours::Config.new.precompiled[:working_hours][1] })
    end

    describe 'validations' do
      it 'rejects empty hash' do
        expect do
          WorkingHours::Config.new.working_hours = {}
        end.to raise_error(WorkingHours::InvalidConfiguration, 'No working hours given')
      end

      it 'rejects invalid day' do
        expect do
          WorkingHours::Config.new.working_hours = { :mon => 1, 'tuesday' => 2, 'wed' => 3 }
        end.to raise_error(WorkingHours::InvalidConfiguration,
                           'Invalid day identifier(s): tuesday, wed - must be 3 letter symbols')
      end

      it 'rejects other type than hash' do
        expect do
          WorkingHours::Config.new.working_hours = { mon: [] }
        end.to raise_error(WorkingHours::InvalidConfiguration, 'Invalid type for `mon`: Array - must be Hash')
      end

      it 'rejects empty range' do
        expect do
          WorkingHours::Config.new.working_hours = { mon: {} }
        end.to raise_error(WorkingHours::InvalidConfiguration, 'No working hours given for day `mon`')
      end

      it 'rejects invalid time format' do
        expect do
          WorkingHours::Config.new.working_hours = { mon: { '8:0' => '12:00' } }
        end.to raise_error(WorkingHours::InvalidConfiguration, "Invalid time: 8:0 - must be 'HH:MM(:SS)'")

        expect do
          WorkingHours::Config.new.working_hours = { mon: { '08:00' => '24:10' } }
        end.to raise_error(WorkingHours::InvalidConfiguration, 'Invalid time: 24:10 - outside of day')
      end

      it 'rejects invalid range' do
        expect do
          WorkingHours::Config.new.working_hours = { mon: { '12:30' => '12:00' } }
        end.to raise_error(WorkingHours::InvalidConfiguration, 'Invalid range: 12:30 => 12:00 - ends before it starts')
      end

      it 'rejects overlapping range' do
        expect do
          WorkingHours::Config.new.working_hours = { mon: { '08:00' => '13:00', '12:00' => '18:00' } }
        end.to raise_error(WorkingHours::InvalidConfiguration,
                           'Invalid range: 12:00 => 18:00 - overlaps previous range')
      end

      it 'does not reject out-of-order, non-overlapping ranges' do
        expect do
          WorkingHours::Config.new.working_hours = { mon: { '10:00' => '11:00', '08:00' => '09:00' } }
        end.not_to raise_error
      end

      it 'raises an error when precompiling if working hours are invalid after assignment' do
        WorkingHours::Config.new.working_hours = { mon: { '10:00' => '11:00', '08:00' => '09:00' } }
        WorkingHours::Config.new.working_hours[:mon] = 'Not correct'
        expect do
          1.working.hour.ago
        end.to raise_error(WorkingHours::InvalidConfiguration, 'Invalid type for `mon`: String - must be Hash')
      end
    end
  end

  describe '#holiday_hours' do
    let(:config) { WorkingHours::Config.new.holiday_hours }
    let(:config2) { { Date.new(2019, 12, 1) => { '08:00' => '14:00' } } }
    let(:config3) { { Date.new(2019, 12, 2) => { '10:00' => '16:00' } } }

    it 'has a default config' do
      expect(config).to be_kind_of(Hash)
    end

    it 'is thread safe' do
      expect(WorkingHours::Config.new.holiday_hours).to eq(config)

      thread = Thread.new do
        WorkingHours::Config.new.holiday_hours = config2
        expect(WorkingHours::Config.new.holiday_hours).to eq(config2)
        Thread.stop
        expect(WorkingHours::Config.new.holiday_hours).to eq(config2)
      end

      expect do
        sleep 0.1 # let the thread begin its execution
      end.not_to change { WorkingHours::Config.new.holiday_hours }.from(config)

      expect do
        WorkingHours::Config.new.holiday_hours = config3
      end.to change { WorkingHours::Config.new.holiday_hours }.from(config).to(config3)

      expect do
        thread.run
        thread.join
      end.not_to change { WorkingHours::Config.new.holiday_hours }.from(config3)
    end

    it 'is fiber safe' do
      expect(WorkingHours::Config.new.holiday_hours).to eq(config)

      fiber = Fiber.new do
        WorkingHours::Config.new.holiday_hours = config2
        expect(WorkingHours::Config.new.holiday_hours).to eq(config2)
        Fiber.yield
        expect(WorkingHours::Config.new.holiday_hours).to eq(config2)
      end

      expect do
        fiber.resume
      end.not_to change { WorkingHours::Config.new.holiday_hours }.from(config)

      expect do
        WorkingHours::Config.new.holiday_hours = config3
      end.to change { WorkingHours::Config.new.holiday_hours }.from(config).to(config3)

      expect do
        fiber.resume
      end.not_to change { WorkingHours::Config.new.holiday_hours }.from(config3)
    end

    it 'is initialized from last known global config' do
      config = WorkingHours::Config.new
      config.holiday_hours = { Date.new(2019, 12, 1) => { '08:00' => '14:00' } }
      Thread.new do
        expect(config.holiday_hours).to match Date.new(2019, 12, 1) => { '08:00' => '14:00' }
      end.join
    end

    it 'should support multiple timespan per day' do
      time_sheet = { Date.new(2019, 12, 1) => { '08:00' => '12:00', '14:00' => '18:00' } }
      WorkingHours::Config.new.holiday_hours = time_sheet
      expect(config).to eq(time_sheet)
    end

    describe 'validations' do
      it 'rejects invalid day' do
        expect do
          WorkingHours::Config.new.holiday_hours = { Date.new(2019, 12, 1) => 1, 'aaaaaa' => 2 }
        end.to raise_error(WorkingHours::InvalidConfiguration,
                           'Invalid day identifier(s): aaaaaa - must be a Date object')
      end

      it 'rejects other type than hash' do
        expect do
          WorkingHours::Config.new.holiday_hours = { Date.new(2019, 12, 1) => [] }
        end.to raise_error(WorkingHours::InvalidConfiguration, 'Invalid type for `2019-12-01`: Array - must be Hash')
      end

      it 'rejects empty range' do
        expect do
          WorkingHours::Config.new.holiday_hours = { Date.new(2019, 12, 1) => {} }
        end.to raise_error(WorkingHours::InvalidConfiguration, 'No working hours given for day `2019-12-01`')
      end

      it 'rejects invalid time format' do
        expect do
          WorkingHours::Config.new.holiday_hours = { Date.new(2019, 12, 1) => { '8:0' => '12:00' } }
        end.to raise_error(WorkingHours::InvalidConfiguration, "Invalid time: 8:0 - must be 'HH:MM(:SS)'")

        expect do
          WorkingHours::Config.new.holiday_hours = { Date.new(2019, 12, 1) => { '08:00' => '24:10' } }
        end.to raise_error(WorkingHours::InvalidConfiguration, 'Invalid time: 24:10 - outside of day')
      end

      it 'rejects invalid range' do
        expect do
          WorkingHours::Config.new.holiday_hours = { Date.new(2019, 12, 1) => { '12:30' => '12:00' } }
        end.to raise_error(WorkingHours::InvalidConfiguration, 'Invalid range: 12:30 => 12:00 - ends before it starts')
      end

      it 'rejects overlapping range' do
        expect do
          WorkingHours::Config.new.holiday_hours = { Date.new(2019, 12, 1) => { '08:00' => '13:00', '12:00' => '18:00' } }
        end.to raise_error(WorkingHours::InvalidConfiguration,
                           'Invalid range: 12:00 => 18:00 - overlaps previous range')
      end

      it 'does not reject out-of-order, non-overlapping ranges' do
        expect do
          WorkingHours::Config.new.holiday_hours = { Date.new(2019, 12, 1) => { '10:00' => '11:00', '08:00' => '09:00' } }
        end.not_to raise_error
      end

      it 'raises an error when precompiling if working hours are invalid after assignment' do
        WorkingHours::Config.new.holiday_hours = { Date.new(2019, 12, 1) => { '10:00' => '11:00', '08:00' => '09:00' } }
        WorkingHours::Config.new.holiday_hours[Date.new(2019, 12, 1)] = 'Not correct'
        expect do
          1.working.hour.ago
        end.to raise_error(WorkingHours::InvalidConfiguration, 'Invalid type for `2019-12-01`: String - must be Hash')
      end
    end
  end

  describe '#holidays' do
    let(:config) { WorkingHours::Config.new.holidays }

    it 'has a default config' do
      expect(config).to eq([])
    end

    it 'should be changeable' do
      WorkingHours::Config.new.holidays = [Date.today]
      expect(config).to eq([Date.today])
    end

    it 'recomputes precompiled when modified' do
      expect do
        WorkingHours::Config.new.holidays << Date.today
      end.to change { WorkingHours::Config.new.precompiled[:holidays] }.by(Set.new([Date.today]))
    end

    it 'is initialized from last known global config' do
      config = WorkingHours::Config.new
      config.holidays = [Date.today]
      Thread.new do
        expect(config.holidays).to eq [Date.today]
      end.join
    end

    describe 'validation' do
      it 'rejects types that cannot be converted into an array' do
        expect do
          WorkingHours::Config.new.holidays = Object.new
        end.to raise_error(WorkingHours::InvalidConfiguration,
                           'Invalid type for holidays: Object - must act like an array')
      end

      it 'rejects invalid day' do
        expect do
          WorkingHours::Config.new.holidays = [Date.today, 42]
        end.to raise_error(WorkingHours::InvalidConfiguration, 'Invalid holiday: 42 - must be Date')
      end

      it 'raises an error when precompiling if holidays are invalid after assignment' do
        WorkingHours::Config.new.holidays = [Date.today]
        WorkingHours::Config.new.holidays << 42
        expect do
          1.working.hour.ago
        end.to raise_error(WorkingHours::InvalidConfiguration, 'Invalid holiday: 42 - must be Date')
      end
    end
  end

  describe '#time_zone' do
    let(:config) { WorkingHours::Config.new.time_zone }

    it 'defaults to UTC' do
      expect(config).to eq(ActiveSupport::TimeZone['UTC'])
    end

    it 'should accept a String' do
      WorkingHours::Config.new.time_zone = 'Tokyo'
      expect(config).to eq(ActiveSupport::TimeZone['Tokyo'])
    end

    it 'should accept a TimeZone' do
      WorkingHours::Config.new.time_zone = ActiveSupport::TimeZone['Tokyo']
      expect(config).to eq(ActiveSupport::TimeZone['Tokyo'])
    end

    it 'is initialized from last known global config' do
      config = WorkingHours::Config.new
      config.time_zone = ActiveSupport::TimeZone['Tokyo']
      Thread.new do
        expect(config.time_zone).to eq ActiveSupport::TimeZone['Tokyo']
      end.join
    end

    it 'recomputes precompiled when modified' do
      expect do
        WorkingHours::Config.new.time_zone.instance_variable_set(:@name, 'Bordeaux')
      end.to change { WorkingHours::Config.new.time_zone.name }.from('UTC').to('Bordeaux')
    end

    describe 'validation' do
      it 'rejects invalid types' do
        expect do
          WorkingHours::Config.new.time_zone = 0o2
        end.to raise_error(WorkingHours::InvalidConfiguration, 'Invalid time zone: 2 - must be String or ActiveSupport::TimeZone')
      end

      it 'rejects unknown time zone' do
        expect do
          WorkingHours::Config.new.time_zone = 'Bordeaux'
        end.to raise_error(WorkingHours::InvalidConfiguration, 'Unknown time zone: Bordeaux')
      end

      it 'raises an error when precompiling if timezone is invalid after assignment' do
        WorkingHours::Config.new.time_zone = 'Paris'
        WorkingHours::Config.new.holidays << ' NotACity'
        expect do
          1.working.hour.ago
        end.to raise_error(WorkingHours::InvalidConfiguration, 'Invalid holiday:  NotACity - must be Date')
      end
    end
  end

  describe '#precompiled' do
    subject { WorkingHours::Config.new.precompiled }

    it 'computes an optimized version' do
      expect(subject).to eq({
                              working_hours: [{}, { 32_400 => 61_200 }, { 32_400 => 61_200 }, { 32_400 => 61_200 },
                                              { 32_400 => 61_200 }, { 32_400 => 61_200 }, {}],
                              holiday_hours: {},
                              holidays: Set.new([]),
                              time_zone: ActiveSupport::TimeZone['UTC']
                            })
    end

    it 'includes default values for each days so computation does not fail' do
      WorkingHours::Config.new.working_hours = { mon: { '08:00' => '14:00' } }
      expect(subject[:working_hours]).to eq([{}, { 28_800 => 50_400 }, {}, {}, {}, {}, {}])
      expect(WorkingHours.working_time_between(Time.utc(2014, 4, 14, 0), Time.utc(2014, 4, 21, 0))).to eq(3600 * 6)
      expect(WorkingHours.add_seconds(Time.utc(2014, 4, 14, 0), 3600 * 7)).to eq(Time.utc(2014, 4, 21, 9))
    end

    it 'supports seconds' do
      WorkingHours::Config.new.working_hours = { mon: { '20:32:59' => '22:59:59' } }
      expect(subject).to eq({
                              working_hours: [{}, { 73_979 => 82_799 }, {}, {}, {}, {}, {}],
                              holiday_hours: {},
                              holidays: Set.new([]),
                              time_zone: ActiveSupport::TimeZone['UTC']
                            })
    end

    it 'supports 24:00 (converts to 23:59:59.999999)' do
      WorkingHours::Config.new.working_hours = { mon: { '20:00' => '24:00' } }
      expect(subject).to eq({
                              working_hours: [{}, { 72_000 => 86_399.999999 }, {}, {}, {}, {}, {}],
                              holiday_hours: {},
                              holidays: Set.new([]),
                              time_zone: ActiveSupport::TimeZone['UTC']
                            })
    end

    it 'changes if working_hours changes' do
      expect do
        WorkingHours::Config.new.working_hours = { mon: { '08:00' => '14:00' } }
      end.to change {
        WorkingHours::Config.new.precompiled[:working_hours]
      }.from(
        [{}, { 32_400 => 61_200 }, { 32_400 => 61_200 }, { 32_400 => 61_200 }, { 32_400 => 61_200 },
         { 32_400 => 61_200 }, {}]
      ).to(
        [{}, { 28_800 => 50_400 }, {}, {}, {}, {}, {}]
      )
    end

    it 'changes if time_zone changes' do
      expect do
        WorkingHours::Config.new.time_zone = 'Tokyo'
      end.to change {
        WorkingHours::Config.new.precompiled[:time_zone]
      }.from(ActiveSupport::TimeZone['UTC']).to(ActiveSupport::TimeZone['Tokyo'])
    end

    it 'changes if holidays changes' do
      expect do
        WorkingHours::Config.new.holidays = [Date.new(2014, 8, 1), Date.new(2014, 7, 1)]
      end.to change {
        WorkingHours::Config.new.precompiled[:holidays]
      }.from(Set.new([])).to(Set.new([Date.new(2014, 8, 1), Date.new(2014, 7, 1)]))
    end

    it 'changes if config is reset' do
      WorkingHours::Config.new.time_zone = 'Tokyo'
      expect do
        WorkingHours::Config.new.reset!
      end.to change {
        WorkingHours::Config.new.precompiled[:time_zone]
      }.from(ActiveSupport::TimeZone['Tokyo']).to(ActiveSupport::TimeZone['UTC'])
    end

    it 'is computed only once' do
      precompiled = WorkingHours::Config.new.precompiled
      3.times { WorkingHours::Config.new.precompiled }
      expect(WorkingHours::Config.new.precompiled).to be(precompiled)
    end
  end

  describe '#with_config' do
    let(:working_hours) { { mon: { '08:00' => '19:00' } } }
    let(:holidays) { [Date.new(2014, 11, 15)] }
    let(:time_zone) { ActiveSupport::TimeZone.new('Paris') }

    it 'sets the corresponding config inside the block' do
      WorkingHours::Config.new.with_config(working_hours: working_hours, holidays: holidays, time_zone: time_zone) do
        expect(WorkingHours::Config.new.working_hours).to eq(working_hours)
        expect(WorkingHours::Config.new.holidays).to eq(holidays)
        expect(WorkingHours::Config.new.time_zone).to eq(time_zone)
      end
    end

    it 'resets to old config after the block' do
      WorkingHours::Config.new.working_hours = { tue: { '09:00' => '16:00' } }
      WorkingHours::Config.new.holidays = [Date.new(2014, 0o1, 0o1)]
      WorkingHours::Config.new.time_zone = ActiveSupport::TimeZone.new('Tokyo')
      WorkingHours::Config.new.with_config(working_hours: working_hours, holidays: holidays, time_zone: time_zone) {}
      expect(WorkingHours::Config.new.working_hours).to eq({ tue: { '09:00' => '16:00' } })
      expect(WorkingHours::Config.new.holidays).to eq([Date.new(2014, 0o1, 0o1)])
      expect(WorkingHours::Config.new.time_zone).to eq(ActiveSupport::TimeZone.new('Tokyo'))
    end

    it 'resets to old config after the block even if things go bad' do
      WorkingHours::Config.new.working_hours = { tue: { '09:00' => '16:00' } }
      WorkingHours::Config.new.holidays = [Date.new(2014, 0o1, 0o1)]
      WorkingHours::Config.new.time_zone = ActiveSupport::TimeZone.new('Tokyo')
      begin
        WorkingHours::Config.new.with_config(working_hours: working_hours, holidays: holidays, time_zone: time_zone) do
          raise
        end
      rescue StandardError
      end
      expect(WorkingHours::Config.new.working_hours).to eq({ tue: { '09:00' => '16:00' } })
      expect(WorkingHours::Config.new.holidays).to eq([Date.new(2014, 0o1, 0o1)])
      expect(WorkingHours::Config.new.time_zone).to eq(ActiveSupport::TimeZone.new('Tokyo'))
    end

    it 'raises if working_hours are invalid' do
      expect { WorkingHours::Config.new.with_config(working_hours: {}) {} }.to raise_error(WorkingHours::InvalidConfiguration)
    end

    it 'raises if holidays are invalid' do
      expect { WorkingHours::Config.new.with_config(holidays: [1]) {} }.to raise_error(WorkingHours::InvalidConfiguration)
    end

    it 'raises if timezone is invalid' do
      expect { WorkingHours::Config.new.with_config(time_zone: '67P Comet') {} }.to raise_error(WorkingHours::InvalidConfiguration)
    end
  end
end
