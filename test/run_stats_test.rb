require_relative "test_helper"

class RunStatsTest < Minitest::Test
  NOW = Time.utc(2026, 10, 7, 15, 10)

  def test_counts_delays_and_longest_gap
    times = [
      Time.utc(2026, 10, 7, 13, 4),  # 4 min late
      Time.utc(2026, 10, 7, 13, 41), # 11 min late
      Time.utc(2026, 10, 7, 15, 9)   # 9 min late, after a 1 h 28 min gap
    ]
    stats = IkeaWatch::RunStats.summarize(times, now: NOW)

    assert_equal 3, stats.count
    assert_equal 48, stats.expected
    assert_equal 8, stats.average_delay
    assert_equal 11, stats.max_delay
    assert_equal (24 * 60) - (2 * 60 + 6), stats.longest_gap # from the window start to the first run
  end

  def test_no_runs
    stats = IkeaWatch::RunStats.summarize([], now: NOW)

    assert_equal 0, stats.count
    assert_nil stats.average_delay
    assert_equal 24 * 60, stats.longest_gap
  end

  def test_fetch_is_skipped_outside_github_actions
    assert_nil IkeaWatch::RunStats.fetch(repository: nil, token: nil)
  end

  def test_message_lines
    stats = IkeaWatch::RunStats.new(count: 44, expected: 48, average_delay: 7, max_delay: 23, longest_gap: 72)

    assert_equal [
      "Scheduled runs in the last 24 h: 44 of 48",
      "Start delay after :00/:30: 7 min on average, 23 min at most",
      "Longest gap between runs: 1 h 12 min"
    ], IkeaWatch::Message.run_stats(stats)
  end

  def test_message_without_stats
    assert_includes only(IkeaWatch::Message.run_stats(nil)), "unavailable"
  end
end
