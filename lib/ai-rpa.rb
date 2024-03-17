

require 'down' #, '~>5.4.1'
require 'openai' #, '~>6.3.1'
require 'adspower-client' #, '~>1.0.8'
require 'my-dropbox-api' #, '~>1.0.1'
require 'colorize' #, '~>0.8.1'
require 'pry' #, '~>0.14.1'
require 'blackstack-core' #, '~>1.2.15'
require 'blackstack-nodes' #, '~>1.2.12'
require 'simple_cloud_logging' #, '~>1.2.2'
require 'simple_command_line_parser' #, '~>1.1.2'

module BlackStack
    class Jarvis
        @@openai_api_key = nil
        @@openai_model = nil
        @@adspower_api_key = nil
        @@dropbox_refresh_token = nil
    
        # for internal use only
        def self.openai(prompt)
            client = OpenAI::Client.new(access_token: OPENAI_API_KEY)
            ret = client.chat(
                parameters: {
                    model: OPENAI_MODEL, # Required.
                    temperature: 0.5,
                    messages: [
                        { role: "user", content: prompt},
                    ], # Required.
                }
            )
            raise "OpenAI Error (code:#{ret['error']['code']}) - #{ret['error']['message']}" if ret['error']
            raise "OpenAI Unkown Error: #{ret.to_s}" if ret['choices'].nil? || ret['choices'].size == 0
            ret['choices'][0]['message']['content']
        end
    end # class Jarvis
end # module BlackStack