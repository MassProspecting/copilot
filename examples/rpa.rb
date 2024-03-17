require 'lib/ai-rpa'
require 'config'

client = OpenAI::Client.new(access_token: OPENAI_API_KEY)