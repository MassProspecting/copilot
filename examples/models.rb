require 'colorize'
require 'pry'
require 'openai' #, '~>6.3.1'
require 'config'

client = OpenAI::Client.new(access_token: OPENAI_API_KEY)
#client = OpenAI::Client.new(access_token: 'dfdf') # enable this line to make it fail
binding.pry

models = client.models.list['data'].select { |model| 
    model['id'] =~ /^gpt\-/i 
}.map { |model| 
    model['id'] 
}.sort_by {
    |model| model
}.uniq