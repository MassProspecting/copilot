require 'lib/ai-rpa'
require 'config'

client = BlackStack::Jarvis.new(
    openai_api_key: OPENAI_API_KEY,
    openai_model: OPENAI_MODEL,
)

client.console

#p client.chat("Please tell me what folders are in the home directory in the local computer.")
#p client.chat('What is the weather like in San Francisco?')
#p client.chat('Hello Jarvis.')