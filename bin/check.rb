#!/usr/bin/env ruby
# Checks IKEA Mexico availability and sends a Telegram alert when it changes.
#
#   ruby bin/check.rb            # check, notify, update state.json
#   ruby bin/check.rb --dry-run  # print the snapshot and message; send and write nothing
#   --heartbeat                  # include the daily check-in now, whatever the time

require_relative "../lib/ikea_watch"

dry_run = ARGV.include?("--dry-run")
force_heartbeat = ARGV.include?("--heartbeat")

begin
  config = IkeaWatch::Config.from_env
  unless dry_run
    raise IkeaWatch::ConfigError, "TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID are required (or use --dry-run)" unless config.telegram_configured?

    config.validate_telegram!
  end
rescue IkeaWatch::ConfigError => e
  abort "Configuration error: #{e.message}"
end

IkeaWatch::Runner.new(
  config:,
  client: IkeaWatch::Client.new(client_id: config.client_id),
  notifier: IkeaWatch::Telegram.new(token: config.telegram_token, chat_id: config.telegram_chat_id),
  state: IkeaWatch::State.load(config.state_path),
  heartbeat: IkeaWatch::Heartbeat.new(hour: config.heartbeat_hour),
  run_stats: -> { IkeaWatch::RunStats.fetch(repository: config.github_repository, token: config.github_token) },
  force_heartbeat:,
  dry_run:
).run
