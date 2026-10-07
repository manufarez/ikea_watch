#!/usr/bin/env ruby
# Checks IKEA Mexico availability and sends a Telegram alert when it changes.
#
#   ruby bin/check.rb            # check, notify, update state.json
#   ruby bin/check.rb --dry-run  # print the snapshot and message; send and write nothing

require_relative "../lib/ikea_watch"

dry_run = ARGV.include?("--dry-run")

begin
  config = IkeaWatch::Config.from_env
rescue IkeaWatch::ConfigError => e
  abort "Configuration error: #{e.message}"
end

unless dry_run || config.telegram_configured?
  abort "Configuration error: TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID are required (or use --dry-run)"
end

IkeaWatch::Runner.new(
  config:,
  client: IkeaWatch::Client.new(client_id: config.client_id),
  notifier: IkeaWatch::Telegram.new(token: config.telegram_token, chat_id: config.telegram_chat_id),
  state: IkeaWatch::State.load(config.state_path),
  dry_run:
).run
