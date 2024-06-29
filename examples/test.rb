# This example is for testing if the API key is valid.
# 
# To run this example, you need to create a file named 'config.rb' in the same folder of this file.
# 
# The RUBYLIB must be set to the root folder of the project, where the file 'config.rb' is located.
# 

require 'colorize'
require 'openai' #, '~>6.3.1'
require 'config'

client = OpenAI::Client.new(access_token: OPENAI_API_KEY)
#client = OpenAI::Client.new(access_token: 'dfdf') # enable this line to make it fail

puts "OpenAI API Key: #{client.access_token.to_s.blue}"

puts client.chat(
    parameters: {
        model: OPENAI_MODEL, # Required.
        messages: [{ role: "user", content: "Hello!"}], # Required.
        temperature: 0.7,
})