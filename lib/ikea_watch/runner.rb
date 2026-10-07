module IkeaWatch
  # One check: fetch, compare with the previous snapshot, notify, then save state.
  # State is saved only after Telegram accepted the message, so a failed send is retried next run.
  class Runner
    def initialize(config:, client:, notifier:, state:, dry_run: false, out: $stdout)
      @config = config
      @client = client
      @notifier = notifier
      @state = state
      @dry_run = dry_run
      @out = out
    end

    def run
      response = @client.fetch(@config.item_nos)
    rescue Client::Error => e
      handle_failure(e)
    else
      handle_success(response)
    end

    private

    def handle_failure(error)
      @out.puts "Check failed: #{error.message}"
      return if @dry_run

      alert = @state.record_failure
      deliver(Message.outage(@state.consecutive_failures, error.message)) if alert
      @state.save
    end

    def handle_success(response)
      current = Parser.call(response, item_nos: @config.item_nos, stores: @config.stores)
      missing = @config.item_nos - current.keys
      @out.puts "Not found in API response: #{missing.join(", ")}" if missing.any?

      text = success_message(current)
      report(current, text) if @dry_run
      return if @dry_run

      deliver(text) if text
      @state.update_items(current, @config.item_nos)
      @state.save
    end

    def success_message(current)
      previous = @state.items
      recovered_after = @dry_run ? nil : @state.record_success
      new_items = current.reject { |item_no, _| previous.key?(item_no) }
      changes = Diff.call(previous, current)

      parts = []
      parts << Message.recovered(recovered_after) if recovered_after
      parts << Message.started(new_items) if new_items.any?
      parts << Message.changes(changes) if changes.any?
      parts.empty? ? nil : parts.join("\n\n")
    end

    def deliver(text)
      @notifier.send_message(text)
      @out.puts "Telegram message sent"
    end

    def report(current, text)
      @out.puts "Snapshot:", JSON.pretty_generate(current), ""
      @out.puts text ? "Message:\n#{text}" : "No changes, nothing to send"
    end
  end
end
