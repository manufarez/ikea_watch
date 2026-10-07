require "json"

module IkeaWatch
  # Persists the last snapshot and API health in state.json.
  # The file is rewritten only when its content changes, so the GitHub Action commits only real changes.
  class State
    FAILURE_THRESHOLD = 3

    attr_reader :path, :data

    def self.load(path)
      data = File.exist?(path) ? JSON.parse(File.read(path)) : {}
      new(path, data)
    end

    def initialize(path, data = {})
      @path = path
      @data = { "items" => {}, "consecutive_failures" => 0, "outage_alerted" => false }.merge(data)
    end

    def items = data["items"]

    def consecutive_failures = data["consecutive_failures"]

    def first_run? = items.empty?

    # Keeps only watched items, so removing one from ITEM_NOS drops it from state.
    def update_items(current, item_nos)
      data["items"] = items.merge(current).slice(*item_nos)
    end

    # Returns true exactly once per outage, when the threshold is reached.
    def record_failure
      data["consecutive_failures"] += 1
      return false if data["outage_alerted"] || consecutive_failures < FAILURE_THRESHOLD

      data["outage_alerted"] = true
    end

    # Returns the failure count if an outage alert had been sent, so a recovery message can follow.
    def record_success
      failures = consecutive_failures
      alerted = data["outage_alerted"]
      data["consecutive_failures"] = 0
      data["outage_alerted"] = false
      failures if alerted
    end

    def to_json = "#{JSON.pretty_generate(data)}\n"

    def save
      return if File.exist?(path) && File.read(path) == to_json

      File.write(path, to_json)
    end
  end
end
