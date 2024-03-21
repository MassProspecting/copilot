
=begin
- Add a persona like Jarvis who reply with short sentences.
- Prevent infinite loops in the chat method when calling functions.
- Add a method to run a command in a remote computer.
- Add a method to wait some time?
- Add a method to operate AdsPower: open and stop browsers, visit a URL, understand the page with CV, operate the page with clicks and keyboard.
- Add voice recognition.
- Add voice synthesis.
=end

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
        @@openai_client = nil
        @@openai_assistant_id = nil
        @@openai_thread_id = nil
        @@openai_message_ids = []

        @@adspower_api_key = nil
        @@dropbox_refresh_token = nil
    
        def initialize(h={})
            errors = []

            errors << ':openai_api_key is mandatory' if h[:openai_api_key].nil?
            errors << ':openai_model is mandatory' if h[:openai_model].nil?
            #errors << ':adspower_api_key is mandatory' if h[:adspower_api_key].nil?
            #errors << ':dropbox_refresh_token is mandatory' if h[:dropbox_refresh_token].nil?
            raise "Jarvis Initialization Error: #{errors.join(', ')}" if errors.size > 0

            @@openai_api_key = h[:openai_api_key] if h[:openai_api_key]
            @@openai_model = h[:openai_model] if h[:openai_model]
            @@openai_client = OpenAI::Client.new(access_token: @@openai_api_key)

            response = @@openai_client.assistants.create(
                parameters: {
                    model: @@openai_model,         # Retrieve via client.models.list. Assistants need 'gpt-3.5-turbo-1106' or later.
                    name: "OpenAI-Ruby test assistant", 
                    description: nil,
                    instructions: OPENAI_INSTRUCTIONS,
                    metadata: { my_internal_version_id: '1.0.0' }
                }
            )
            @@openai_assistant_id = response["id"]
            
            # Create thread
            response = @@openai_client.threads.create   # Note: Once you create a thread, there is no way to list it
                                                        # or recover it currently (as of 2023-12-10). So hold onto the `id` 
            @@openai_thread_id = response["id"]
            
            # adspower
            @@adspower_api_key = h[:adspower_api_key] if h[:adspower_api_key]

            # dropbox
            @@dropbox_refresh_token = h[:dropbox_refresh_token] if h[:dropbox_refresh_token]
        end

        # for internal use only
        def run_command_in_local_computer(command:)
            ret = `#{command}`
            ret
        end        

        # for internal use only
        def chat1(prompt)
            ret = @@openai_client.chat(
                parameters: {
                    model: @@openai_model, # Required.
                    temperature: 0.5,
                    messages: [
                        { 
                            role: "user",
                            content: prompt
                        },
                    ], # Required.
                    functions: [
                        {
                            name: "run_command_in_local_computer",
                            description: "Run a bash command in the local computer",
                            parameters: {
                                type: :object,
                                properties: {
                                command: {
                                    type: :string,
                                    description: "A bash command.",
                                },
                                },
                                required: ["command"],
                            },
                        },
                    ],
                }
            )
            raise "OpenAI Error (code:#{ret['error']['code']}) - #{ret['error']['message']}" if ret['error']
            raise "OpenAI Unkown Error: #{ret.to_s}" if ret['choices'].nil? || ret['choices'].size == 0

            message = ret['choices'][0]['message']
            
            if message["role"] == "assistant" && message["function_call"]
                function_name = message.dig("function_call", "name")
                args =
                  JSON.parse(
                    message.dig("function_call", "arguments"),
                    { symbolize_names: true },
                  )
              
                case function_name
                when "run_command_in_local_computer"
                    s = run_command_in_local_computer(**args)
                when "get_current_weather"
                    s = get_current_weather(**args)
                end # case function_name
                return self.chat("#{prompt}.\n\nDon't call any function. Here is the output of the regarding function that you already called: #{s}")
            else
                return message["content"]
            end # if message["role"] == "assistant" && message["function_call"]
        end # def chat1

        # for internal use only
        def chat2(prompt)
            # create the new message
            mid = @@openai_client.messages.create(
                thread_id: @@openai_thread_id,
                parameters: {
                    role: "user", # Required for manually created messages
                    content: prompt, # Required.
                }
            )["id"]
            @@openai_message_ids << mid

            # run the assistant
            response = @@openai_client.runs.create(
                thread_id: @@openai_thread_id,
                parameters: {
                    assistant_id: @@openai_assistant_id
                }
            )
            run_id = response['id']
            
            # wait for a response
            while true do    
                response = @@openai_client.runs.retrieve(id: run_id, thread_id: @@openai_thread_id)
                status = response['status']
            
                case status
                when 'queued', 'in_progress', 'cancelling'
                    sleep 1 # Wait one second and poll again
                when 'completed'
                    break # Exit loop and report result to user
                when 'requires_action'
                    # Handle tool calls (see below)
                when 'cancelled', 'failed', 'expired'
                    break # or `exit`
                else
                    raise "Unknown run status response from OpenAI: #{status}"
                end
            end

            # 
            messages = @@openai_client.messages.list(thread_id: @@openai_thread_id) 
            messages['data'].first['content'].first['text']['value']
        end # def chat2

        def console
            puts "Jarvis Console".blue
            puts "Type 'exit' to quit.".blue
            while true
                print "You: ".green
                prompt = gets.chomp
                break if prompt == 'exit'
                begin
                    puts "Jarvis: #{chat2(prompt)}".blue
                rescue => e
                    puts "Jarvis: #{e.message}".red
                end
            end
        end # def console

    end # class Jarvis
end # module BlackStack