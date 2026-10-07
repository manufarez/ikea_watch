module IkeaWatch
  # Decides when the daily check-in is due: on the first successful run at or after `hour`, once per day.
  # Mexico City has stayed on UTC-6 all year since it dropped daylight saving time in 2022.
  class Heartbeat
    UTC_OFFSET = "-06:00".freeze

    def initialize(hour:, now: Time.now)
      @hour = hour
      @local = now.getlocal(UTC_OFFSET)
    end

    def due?(last_sent_on)
      !@hour.nil? && @local.hour >= @hour && last_sent_on != today
    end

    def today = @local.strftime("%Y-%m-%d")
  end
end
