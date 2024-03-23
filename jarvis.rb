#!~/.rvm/rubies/ruby-3.1.2/bin/ruby

require 'lib/my-jarvis'
require 'config'

client = BlackStack::Jarvis.new(
    openai_api_key: OPENAI_API_KEY,
    openai_model: OPENAI_MODEL,
    adspower_api_key: ADSPOWER_API_KEY,
    dropbox_refresh_token: DB_REFRESH_TOKEN,
)

client.console