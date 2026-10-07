require_relative "test_helper"
require "stringio"

class RunnerTest < Minitest::Test
  class FakeClient
    attr_accessor :response, :error

    def fetch(_item_nos)
      raise IkeaWatch::Client::Error, error if error

      response
    end
  end

  class FakeNotifier
    attr_reader :messages

    def initialize = @messages = []

    def send_message(text) = @messages << text
  end

  def setup
    @dir = Dir.mktmpdir
    @state_path = File.join(@dir, "state.json")
    @config = IkeaWatch::Config.from_env({ "STORE_IDS" => "612,652" }, state_path: @state_path)
    @client = FakeClient.new.tap { it.response = Fixtures.sample_response }
    @notifier = FakeNotifier.new
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def test_first_run_announces_watching_and_saves_state
    run_check

    assert_includes only(@notifier.messages), "👀 Now watching"
    assert_equal Fixtures.sample_snapshot, saved_state["items"]
  end

  def test_unchanged_run_sends_nothing_and_leaves_file_untouched
    run_check
    mtime = File.mtime(@state_path)
    run_check

    assert_equal 1, @notifier.messages.size
    assert_equal mtime, File.mtime(@state_path)
  end

  def test_change_is_notified_and_saved
    run_check
    @client.response = Fixtures.sample_response.tap { it["availabilities"][0]["buyingOption"]["cashCarry"]["availability"]["quantity"] = 0 }
    run_check

    assert_includes @notifier.messages.last, "Oceanía quantity: 1 → <b>0</b>"
    assert_equal 0, saved_state.dig("items", "80600606", "stores", "612", "quantity")
  end

  def test_outage_alert_is_sent_once_after_three_failures_then_recovery
    run_check
    @client.error = "IKEA API returned HTTP 503"
    5.times { run_check }

    assert_equal 2, @notifier.messages.size
    assert_includes @notifier.messages.last, "monitoring is not working"
    assert_equal 5, saved_state["consecutive_failures"]

    @client.error = nil
    run_check

    assert_includes @notifier.messages.last, "working again</b> (after 5 failed checks)"
    assert_equal 0, saved_state["consecutive_failures"]
    refute saved_state["outage_alerted"]
  end

  def test_short_failure_streak_recovers_silently
    run_check
    @client.error = "timeout"
    2.times { run_check }
    @client.error = nil
    run_check

    assert_equal 1, @notifier.messages.size
    assert_equal 0, saved_state["consecutive_failures"]
  end

  def test_failed_telegram_send_does_not_save_state
    notifier = Object.new.tap { it.define_singleton_method(:send_message) { |_| raise IkeaWatch::Telegram::Error, "down" } }

    assert_raises(IkeaWatch::Telegram::Error) { run_check(notifier:) }
    refute File.exist?(@state_path)
  end

  def test_dry_run_prints_without_sending_or_writing
    out = run_check(dry_run: true)

    assert_includes out, "\"online_buyable\": false"
    assert_includes out, "Message:\n👀 Now watching"
    assert_empty @notifier.messages
    refute File.exist?(@state_path)
  end

  private

  def run_check(dry_run: false, notifier: @notifier)
    out = StringIO.new
    state = IkeaWatch::State.load(@state_path)
    IkeaWatch::Runner.new(config: @config, client: @client, notifier:, state:, dry_run:, out:).run
    out.string
  end

  def saved_state = JSON.parse(File.read(@state_path))
end
