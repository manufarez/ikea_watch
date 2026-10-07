# ikea_watch

Watches IKEA Mexico availability for a list of articles and sends a Telegram message when something changes:
whether the item can be bought online, and stock, stock level and restock date at IKEA Oceanía (CDMX) and IKEA Puebla.

Plain Ruby (3.4+, no gems). It runs on GitHub Actions every 30 minutes, with a launchd fallback for a Mac.

```sh
ruby bin/check.rb --dry-run   # print the snapshot and the message, send and write nothing
ruby bin/check.rb             # check, notify, update state.json
rake test                     # minitest suite (uses fixtures/sample.json)
```

## How it works

1. Calls the availability API that ikea.com itself uses (v2):
   `https://api.salesitem.ingka.com/availabilities/ru/mx?itemNos=…`, with the `accept: application/json;version=2` and `x-client-id` headers.
2. Builds a normalized snapshot per article (see `lib/ikea_watch/parser.rb`).
3. Compares it with the previous snapshot in `state.json`. If anything changed, it sends one Telegram message
   (before → after, with a link to the product page), then saves the new state. If the send fails, the state is not saved,
   so the change is reported again on the next run.

### Reading the API response

The response has one entry per location in `availabilities`, keyed by `classUnitKey`:

| `classUnitType` / `classUnitCode` | Meaning |
|---|---|
| `STO` / `612` | IKEA Oceanía (CDMX) |
| `STO` / `652` | IKEA Puebla |
| `STO` / `683` | IKEA Guadalajara Expo |
| `STO` / `634` | Not a public store (warehouse, coworker pickup) |
| `RU` / `MX` | **Online sales for the whole country** |

**Buyable online** means `availableForHomeDelivery == true` on the `RU` entry. This is what drives the
"Agotado en línea" button on ikea.com. Do not rely on `buyingOption.homeDelivery.range.inRange`: it only says the
article belongs to the deliverable range, and it is `true` even when the article is sold out. Third-party sites that show
"Home Delivery: Available" are most likely reading that field.

Store stock comes from `buyingOption.cashCarry.availability.quantity`, and the stock level from
`…availability.probability.thisDay.messageType` (`HIGH_IN_STOCK`, `MEDIUM_IN_STOCK`, `LOW_IN_STOCK`, `OUT_OF_STOCK`).

Restock dates: the sample response contains no restock data, so their exact format is not confirmed yet. The parser looks
for a `restocks` list on the buying option and keeps the earliest `earliestDate`/`date`. If it finds a `restocks` list it
cannot read, it logs a warning. When that happens, save the real response as a fixture and adjust the parser.

### Snapshot (`state.json`)

```json
{
  "items": {
    "80600606": {
      "online_buyable": false,
      "online_probability": "OUT_OF_STOCK",
      "online_restock_date": null,
      "stores": {
        "612": { "name": "Oceanía", "quantity": 1, "probability": "MEDIUM_IN_STOCK", "restock_date": null },
        "652": { "name": "Puebla", "quantity": 5, "probability": "HIGH_IN_STOCK", "restock_date": null }
      }
    }
  },
  "consecutive_failures": 0,
  "outage_alerted": false
}
```

The file is only rewritten when its content changes, so the workflow commits only real changes.

### Messages

- **First run, or a newly added article:** a "Now watching" summary of the current state.
- **Changes:** one line per changed field, for example `Oceanía quantity: 1 → 0`.
- **🚨 Highlighted at the top:** the article becoming buyable online, or a restock date appearing (online or in a store).
- **Outage:** after 3 failed checks in a row, a single "monitoring is not working" alert. A "working again" message
  follows once a check succeeds.

## Configuration

| Variable | Required | Default | Notes |
|---|---|---|---|
| `TELEGRAM_BOT_TOKEN` | yes (except `--dry-run`) | | From @BotFather |
| `TELEGRAM_CHAT_ID` | yes (except `--dry-run`) | | Your chat id |
| `ITEM_NOS` | no | `80600606` | Comma-separated, dots allowed: `806.006.06,123.456.78` |
| `IKEA_CLIENT_ID` | no | the public ikea.com client id | Override if IKEA rotates it |
| `STORE_IDS` | no | `612,652` | Store codes, in display order |

To get a nice name and the exact product URL in messages, add the article to `PRODUCTS` in
`lib/ikea_watch/config.rb`. Without that entry, messages fall back to "Item 123.456.78" and an ikea.com search link.

## Setup

### 1. Create the Telegram bot

1. In Telegram, open a chat with **@BotFather** and send `/newbot`.
2. Choose a display name, then a username ending in `bot` (for example `manu_ikea_watch_bot`).
3. BotFather replies with the **bot token** (`123456789:AA…`). Keep it secret.

### 2. Get your chat id

1. Open a chat with your new bot and send it any message (for example `/start`). Bots cannot message you first.
2. Read the token from the terminal without echoing it, then ask Telegram for the bot's updates:

   ```sh
   read -rs TELEGRAM_BOT_TOKEN && export TELEGRAM_BOT_TOKEN
   curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/getUpdates" \
     | ruby -rjson -e 'JSON.parse(STDIN.read)["result"].each { puts it.dig("message", "chat", "id") }' | sort -u
   ```

3. The number printed is your `TELEGRAM_CHAT_ID`. If nothing prints, send the bot another message and retry.

### 3. Configure GitHub

Push this repository to GitHub, then add the secrets. `gh secret set` prompts for each value, so nothing lands in
your shell history:

```sh
gh secret set TELEGRAM_BOT_TOKEN
gh secret set TELEGRAM_CHAT_ID
# optional
gh variable set ITEM_NOS --body "80600606"
```

You can also do this in the web UI: **Settings → Secrets and variables → Actions**.

Then open **Actions → Check IKEA availability → Run workflow** to run it once by hand. You should receive the
"Now watching" message, and a commit adding `state.json`.

Notes:
- The workflow needs `contents: write` to commit `state.json`. This is set in the workflow, but if the repository
  restricts it, enable **Settings → Actions → General → Workflow permissions → Read and write**.
- GitHub may delay scheduled runs by several minutes when it is busy.
- In public repositories, GitHub disables scheduled workflows after 60 days without activity. Re-enable the workflow
  from the Actions tab if that happens.
- Cost: a public repository is free. A private one uses about 1,440 of the 2,000 free minutes per month,
  because every run is rounded up to one minute.

## Plan B: run it on your Mac with launchd

Use this if the IKEA API starts rejecting GitHub's IP addresses (the run logs would show repeated
`IKEA API returned HTTP 403` errors, and you would get the outage alert).

1. Store the secrets in a file only you can read. Use a terminal editor, not an editor or sync tool
   that could upload the file:

   ```sh
   mkdir -p ~/.config/ikea-watch
   touch ~/.config/ikea-watch/env && chmod 600 ~/.config/ikea-watch/env
   nano ~/.config/ikea-watch/env
   ```

   ```sh
   TELEGRAM_BOT_TOKEN=123456789:AA...
   TELEGRAM_CHAT_ID=123456789
   ITEM_NOS=80600606
   ```

2. Disable the GitHub workflow (Actions → Check IKEA availability → ⋯ → Disable workflow), so both don't notify you.
3. Install and load the agent. The plist assumes the repository is at `/Users/manufarez/Code/ikea_watch`;
   edit the paths if you move it.

   ```sh
   cp launchd/com.manufarez.ikea-watch.plist ~/Library/LaunchAgents/
   launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.manufarez.ikea-watch.plist
   launchctl kickstart gui/$(id -u)/com.manufarez.ikea-watch   # run now
   tail -f ~/Library/Logs/ikea-watch.log
   ```

4. To stop it: `launchctl bootout gui/$(id -u)/com.manufarez.ikea-watch`.

The agent runs every 30 minutes while the Mac is awake, and catches up after sleep. `bin/run-local.sh` puts the mise shims on `PATH`,
so `.ruby-version` selects Ruby 3.4 even though launchd does not load your shell config. `state.json` is then local; it is not committed anywhere.
