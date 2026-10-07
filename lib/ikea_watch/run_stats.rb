require "json"
require "net/http"
require "time"

module IkeaWatch
  # How punctual GitHub's */30 schedule was over the last 24 hours, from the workflow's own run history.
  class RunStats < Data.define(:count, :expected, :average_delay, :max_delay, :longest_gap)
    WINDOW = 24 * 3600
    INTERVAL = 30 * 60

    # start_times: Time objects of scheduled runs within the window.
    def self.summarize(start_times, now:)
      times = start_times.sort
      delays = times.map { (it.to_i % INTERVAL) / 60 } # minutes past :00 or :30
      edges = [now - WINDOW, *times, now]
      gap = edges.each_cons(2).map { |a, b| ((b - a) / 60).round }.max

      new(
        count: times.size,
        expected: WINDOW / INTERVAL,
        average_delay: delays.empty? ? nil : (delays.sum.to_f / delays.size).round,
        max_delay: delays.max,
        longest_gap: gap
      )
    end

    # Returns nil when not running in GitHub Actions or when the API call fails.
    def self.fetch(repository:, token:, now: Time.now)
      return nil unless repository && token

      since = (now - WINDOW).utc.iso8601
      uri = URI("https://api.github.com/repos/#{repository}/actions/workflows/check.yml/runs")
      uri.query = URI.encode_www_form(event: "schedule", created: ">=#{since}", per_page: 100)

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 10, read_timeout: 20) do |http|
        http.get(uri.request_uri, "authorization" => "Bearer #{token}", "accept" => "application/vnd.github+json")
      end
      return nil unless response.is_a?(Net::HTTPSuccess)

      times = JSON.parse(response.body).fetch("workflow_runs").map { Time.parse(it["created_at"]) }
      summarize(times, now:)
    rescue StandardError => e
      warn "Run stats unavailable: #{e.class}"
      nil
    end
  end
end
