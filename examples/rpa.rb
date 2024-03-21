require 'lib/ai-rpa'
require 'config'

client = BlackStack::Jarvis.new(
    openai_api_key: OPENAI_API_KEY,
    openai_model: OPENAI_MODEL,
)

p client.chat("Please tell me what folders are in the home directory in the local computer.")