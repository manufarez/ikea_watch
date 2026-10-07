require_relative "test_helper"

class HeartbeatTest < Minitest::Test
  def test_not_due_before_the_hour_in_mexico_city
    refute heartbeat(Time.utc(2026, 10, 7, 14, 59)).due?(nil) # 08:59 in Mexico City
  end

  def test_due_from_the_hour_until_sent
    beat = heartbeat(Time.utc(2026, 10, 7, 15, 20))

    assert beat.due?(nil)
    assert beat.due?("2026-10-06")
    refute beat.due?("2026-10-07")
  end

  def test_uses_the_mexico_city_date
    assert_equal "2026-10-06", heartbeat(Time.utc(2026, 10, 7, 3)).today # 21:00 the day before
  end

  def test_disabled_when_hour_is_nil
    refute IkeaWatch::Heartbeat.new(hour: nil, now: Time.utc(2026, 10, 7, 20)).due?(nil)
  end

  private

  def heartbeat(now) = IkeaWatch::Heartbeat.new(hour: 9, now:)
end
