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

        @@dropbox_refresh_token = nil
    
        # {'label' => 'foo', 'node' => <BlackStack::Infrastructure::Node object here> }
        @@nodes = []
        
        ## Local Computer Operation
        ##
        ##

        # for internal use only
        def run_command_in_local_computer(command:)
            ret = `#{command}`
            ret
        end  

        ## Remote Computers Operation
        ##
        ##

        # return the list of nodes, with their SSH credentials
        def nodes
            @@nodes
        end

        # add a node to the list of nodes, with username and password access to establish a SSH connection
        # label: a string to identify the node. It must be unique.
        # net_remote_ip: the public IP of the node.
        # ssh_port: the port to connect via SSH. It is usually 22.
        # ssh_username: the username to connect via SSH.
        # ssh_password: the password to connect via SSH.
        def add_node_with_password(h)
            label = h[:label]
            net_remote_ip = h[:net_remote_ip]
            ssh_port = h[:ssh_port]
            ssh_username = h[:ssh_username]
            ssh_password = h[:ssh_password]
            raise 'Already exists a node with this label.' if @@nodes.find { |n| n['label'] == label }
            node = BlackStack::Infrastructure::Node.new(
                :name => label,
                :net_remote_ip => net_remote_ip, 
                :ssh_port => ssh_port, 
                :ssh_username => ssh_username,
                :ssh_password => ssh_password
            )
            @@nodes << { 'label' => label, 'node' => node }
        end # def add_node_with_password

        # add a node to the list of nodes, with username and private key access to establish a SSH connection
        # label: a string to identify the node. It must be unique.
        # net_remote_ip: the public IP of the node.
        # ssh_port: the port to connect via SSH. It is usually 22.
        # ssh_username: the username to connect via SSH.
        # ssh_private_key: the full path to the file in this local computer where to find the private key to connect via SSH.
        def add_node_with_private_key(h)
            label = h[:label]
            net_remote_ip = h[:net_remote_ip]
            ssh_port = h[:ssh_port]
            ssh_username = h[:ssh_username]
            ssh_private_key_filename = h[:ssh_private_key_filename]
            raise 'Already exists a node with this label.' if @@nodes.find { |n| n['label'] == label }
            node = BlackStack::Infrastructure::Node.new(
                :name => label,
                :net_remote_ip => net_remote_ip,
                :ssh_port => ssh_port,
                :ssh_username => ssh_username,
                :ssh_private_key_file => ssh_private_key_filename,
            )
            @@nodes << { 'label' => label, 'node' => node }
        end

        # connect to a node via ssh.
        def connect_node(h)
            label = h[:label]
            n = @@nodes.find { |n| n['label'] == label }
            raise "Node not found." if n.nil?    
            n['node'].connect
        end

        # disconnect from a node via ssh.
        def disconnect_node(h)
            label = h[:label]
            n = @@nodes.find { |n| n['label'] == label }
            raise "Node not found." if n.nil?
            n['node'].disconnect
        end

        # run a command in a node via ssh.
        def run_command_in_node(h)
            label = h[:label]
            command = h[:command]
            n = @@nodes.find { |n| n['label'] == label }
            raise "Node not found." if n.nil?
            n['node'].exec(command)
        end

        # reboot a node via ssh.
        def reboot_node(h)
            label = h[:label]
            n = @@nodes.find { |n| n['label'] == label }
            raise "Node not found." if n.nil?
            n['node'].reboot
        end

        ## Browsers Operation
        ## 
        ## 
        module Browsing
            @@adspower_api_key = nil
            @@drivers = []

            def self.initialize(h)
                @@adspower_api_key = h[:adspower_api_key] if h[:adspower_api_key]
            end

            # start the browser
            #
            # code: the unique ID of the browser.
            #
            def self.start(h)
                code = h[:code]
                client = AdsPowerClient.new(api_key: @@adspower_api_key)
                client.start(code) unless client.check(code)
                @@drivers << { 'code' => code, 'driver' => client.driver(code) }
            end

            # stop the browser
            #
            # code: the unique ID of the browser.
            #
            def self.stop(h)
                code = h[:code]
                client = AdsPowerClient.new(api_key: @@adspower_api_key)
                client.stop(code) if client.check(code)
                # remove eny driver with code
                @@drivers.delete_if { |d| d['code'] == code }
            end

            # return true of the browser is running
            #
            # code: the unique ID of the browser.
            #
            def self.is_running?(h)
                code = h[:code]
                client = AdsPowerClient.new(api_key: @@adspower_api_key)
                client.check(code)
            end

            # visit an URL
            #
            # code: the unique ID of the browser.
            # url: the URL to visit.
            #
            def self.visit(h)
                code = h[:code]
                url = h[:url]
                client = AdsPowerClient.new(api_key: @@adspower_api_key)
                d = @@drivers.find { |d| d['code'] == code }
                raise "Browser not found." if d.nil?
                d['driver'].get(url)
            end

            # scroll horizontally
            #
            # code: the unique ID of the browser.
            # pixels: the number of pixels to scroll. It may be negative or positive, to scroll left or right.
            #
            def self.scroll_horizontally(h)
                code = h[:code]
                pixels = h[:pixels]
                client = AdsPowerClient.new(api_key: @@adspower_api_key)
                d = @@drivers.find { |d| d['code'] == code }
                raise "Browser not found." if d.nil?
                d['driver'].execute_script("window.scrollBy(#{pixels},0)")
            end

            # scroll vertically
            #
            # code: the unique ID of the browser.
            # pixels: the number of pixels to scroll. It may be negative or positive, to scroll up or down.
            #
            def self.scroll_vertically(h)
                code = h[:code]
                pixels = h[:pixels]
                client = AdsPowerClient.new(api_key: @@adspower_api_key)
                d = @@drivers.find { |d| d['code'] == code }
                raise "Browser not found." if d.nil?
                d['driver'].execute_script("window.scrollBy(0,#{pixels})")
            end

            # take a screenshot
            #
            # code: the unique ID of the browser.
            # filename: the full path to the file where to save the screenshot.
            #
            def self.take_screenshot(h)
                code = h[:code]
                filename = OPENAI_JARVIS_BROWSING_SCREENSHOT_FILENAME
                client = AdsPowerClient.new(api_key: @@adspower_api_key)
                d = @@drivers.find { |d| d['code'] == code }
                raise "Browser not found." if d.nil?
                d['driver'].save_screenshot(filename)
            end

            # click on a specific coordinates
            #
            # code: the unique ID of the browser.
            # x: the x coordinate.
            # y: the y coordinate.
            #
            def self.click(h)
                code = h[:code]
                x = h[:x]
                y = h[:y]
                client = AdsPowerClient.new(api_key: @@adspower_api_key)
                d = @@drivers.find { |d| d['code'] == code }
                raise "Browser not found." if d.nil?
                d['driver'].action.move_to(x: x, y: y).click.perform
            end



        end # module Browsing 

        ## Constructor
        ## 
        ## 

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
                    tools: [
                        {"type": "code_interpreter"}, 
                        {"type": "retrieval"}, 
                        ## Local Computer Operation
                        {
                            type: "function",
                            function: {
                                name: "run_command_in_local_computer",
                                description: "Run a bash command in the local computer.",
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
                        ## Remote Computers Operation
                        }, {
                            type: "function",
                            function: {
                                name: "nodes",
                                description: "Return the list of nodes, with their SSH credentials.",
                            },
                        }, {
                            type: "function",
                            function: {
                                name: "add_node_with_password",
                                description: "add a node to the list of nodes, with username and password access to establish a SSH connection.",
                                parameters: {
                                    type: :object,
                                    properties: {
                                        label: {
                                            type: :string,
                                            description: "a string to identify the node. It must be unique.",
                                        },
                                        net_remote_ip: {
                                            type: :string,
                                            description: "the public IP of the node.",
                                        },
                                        ssh_port: {
                                            type: :string,
                                            description: "the port to connect via SSH. It is usually 22.",
                                        },
                                        ssh_username: {
                                            type: :string,
                                            description: "the username to connect via SSH.",
                                        },
                                        ssh_password: {
                                            type: :string,
                                            description: "the password to connect via SSH.",
                                        },
                                    },
                                    required: ['label', 'net_remote_ip', 'ssh_port', 'ssh_username', 'ssh_password'],
                                },    
                            },
                        }, {
                            type: "function",
                            function: {
                                name: "add_node_with_private_key",
                                description: "add a node to the list of nodes, with username and private key access to establish a SSH connection.",
                                parameters: {
                                    type: :object,
                                    properties: {
                                        label: {
                                            type: :string,
                                            description: "a string to identify the node. It must be unique.",
                                        },
                                        net_remote_ip: {
                                            type: :string,
                                            description: "the public IP of the node.",
                                        },
                                        ssh_port: {
                                            type: :string,
                                            description: "the port to connect via SSH. It is usually 22.",
                                        },
                                        ssh_username: {
                                            type: :string,
                                            description: "the username to connect via SSH.",
                                        },
                                        ssh_private_key_filename: {
                                            type: :string,
                                            description: "the full path to the file in this local computer where to find the private key to connect via SSH.",
                                        },
                                    },
                                    required: ["label", "net_remote_ip", "ssh_port", "ssh_username", "ssh_private_key_filename"],
                                },    
                            },
                        }, {
                            type: "function",
                            function: {
                                name: "connect_node",
                                description: "connect to a node via ssh.",
                                parameters: {
                                    type: :object,
                                    properties: {
                                        label: {
                                            type: :string,
                                            description: "a string to identify the node. It must be unique.",
                                        },
                                    },
                                    required: ["label"],
                                },    
                            },
                        }, {
                            type: "function",
                            function: {
                                name: "disconnect_node",
                                description: "disconnect ssh communication to a node.",
                                parameters: {
                                    type: :object,
                                    properties: {
                                        label: {
                                            type: :string,
                                            description: "a string to identify the node. It must be unique.",
                                        },
                                    },
                                    required: ["label"],
                                },    
                            },
                        }, {
                            type: "function",
                            function: {
                                name: "run_command_in_node",
                                description: "run a command in a node via ssh.",
                                parameters: {
                                    type: :object,
                                    properties: {
                                        label: {
                                            type: :string,
                                            description: "a string to identify the node. It must be unique.",
                                        },
                                        command: {
                                            type: :string,
                                            description: "the bash command to run in the node via SSH.",
                                        },
                                    },
                                    required: ["label"],
                                },    
                            },
                        }, {
                            type: "function",
                            function: {
                                name: "reboot_node",
                                description: "reboot a node via ssh.",
                                parameters: {
                                    type: :object,
                                    properties: {
                                        label: {
                                            type: :string,
                                            description: "a string to identify the node. It must be unique.",
                                        },
                                    },
                                    required: ["label"],
                                },    
                            },
                        ## Browsers Operation
                        }, {
                            type: "function",
                            function: {
                                name: "browser_start",
                                description: "Start a browser.",
                                parameters: {
                                    type: :object,
                                    properties: {
                                        code: {
                                            type: :string,
                                            description: "Code of the browser to start.",
                                        },
                                    },
                                    required: ["code"],
                                },    
                            },
                        }, {
                            type: "function",
                            function: {
                                name: "browser_stop",
                                description: "Stop a browser.",
                                parameters: {
                                    type: :object,
                                    properties: {
                                        code: {
                                            type: :string,
                                            description: "Code of the browser to stop.",
                                        },
                                    },
                                    required: ["code"],
                                },    
                            },
                        }, {
                            type: "function",
                            function: {
                                name: "is_running",
                                description: "Return true if the browser is running.",
                                parameters: {
                                    type: :object,
                                    properties: {
                                        code: {
                                            type: :string,
                                            description: "Code of the browser to check.",
                                        },
                                    },
                                    required: ["code"],
                                },    
                            },
                        }, {
                            type: "function",
                            function: {
                                name: "visit",
                                description: "Visit an URL in a browser.",
                                parameters: {
                                    type: :object,
                                    properties: {
                                        code: {
                                            type: :string,
                                            description: "Code of the browser to operate.",
                                        },
                                        url: {
                                            type: :string,
                                            description: "URL to visit.",
                                        },
                                    },
                                    required: ["code", "url"],
                                },    
                            },
                        }, {
                            type: "function",
                            function: {
                                name: "scroll_horizontally",
                                description: "Scroll horizontally in a browser.",
                                parameters: {
                                    type: :object,
                                    properties: {
                                        code: {
                                            type: :string,
                                            description: "Code of the browser to operate.",
                                        },
                                        pixels: {
                                            type: :integer,
                                            description: "Number of pixels to scroll. It may be negative or positive, to scroll left or right.",
                                        },
                                    },
                                    required: ["code", "pixels"],
                                },
                            },
                        }, {
                            type: "function",
                            function: {
                                name: "scroll_vertically",
                                description: "Scroll vertically in a browser.",
                                parameters: {
                                    type: :object,
                                    properties: {
                                        code: {
                                            type: :string,
                                            description: "Code of the browser to operate.",
                                        },
                                        pixels: {
                                            type: :integer,
                                            description: "Number of pixels to scroll. It may be negative or positive, to scroll up or down.",
                                        },
                                    },
                                    required: ["code", "pixels"],
                                },
                            },
                        }, {
                            type: "function",
                            function: {
                                name: "take_screenshot",
                                description: "Take a screenshot in a browser.",
                                parameters: {
                                    type: :object,
                                    properties: {
                                        code: {
                                            type: :string,
                                            description: "Code of the browser to operate.",
                                        },
                                    },
                                    required: ["code"],
                                },
                            },
                        }, {
                            type: "function",
                            function: {
                                name: "click",
                                description: "Click on a specific coordinates in a browser.",
                                parameters: {
                                    type: :object,
                                    properties: {
                                        code: {
                                            type: :string,
                                            description: "Code of the browser to operate.",
                                        },
                                        x: {
                                            type: :integer,
                                            description: "X coordinate.",
                                        },
                                        y: {
                                            type: :integer,
                                            description: "Y coordinate.",
                                        },
                                    },
                                    required: ["code", "x", "y"],
                                },
                            },
                        }
                    ],
                    metadata: { my_internal_version_id: '1.0.0' },
                }
            )
            @@openai_assistant_id = response["id"]
            
            # Create thread
            response = @@openai_client.threads.create   # Note: Once you create a thread, there is no way to list it
                                                        # or recover it currently (as of 2023-12-10). So hold onto the `id` 
            @@openai_thread_id = response["id"]
            
            # adspower
            BlackStack::Jarvis::Browsing.initialize(h)

            # dropbox
            @@dropbox_refresh_token = h[:dropbox_refresh_token] if h[:dropbox_refresh_token]
        end


        ## AI Methods
        ##
        ##

        # for internal use only
        def chat(prompt)
            # create the new message
            mid = @@openai_client.messages.create(
                thread_id: @@openai_thread_id,
                parameters: {
                    role: "user", # Required for manually created messages
                    content: prompt, # Required.
                },
            )["id"]
            @@openai_message_ids << mid

            # run the assistant
            response = @@openai_client.runs.create(
                thread_id: @@openai_thread_id,
                parameters: {
                    assistant_id: @@openai_assistant_id,
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
                    tools_to_call = response.dig('required_action', 'submit_tool_outputs', 'tool_calls')

                    my_tool_outputs = tools_to_call.map { |tool|
                        # Call the functions based on the tool's name
                        function_name = tool.dig('function', 'name')
                        arguments = JSON.parse(
                              tool.dig("function", "arguments"),
                              { symbolize_names: true },
                        )
                        
                        begin
                            tool_output = case function_name
                            ## Local Computer Operation
                            when "run_command_in_local_computer"
                                run_command_in_local_computer(**arguments)
                            ## Remote Computers Operation
                            when "nodes"
                                nodes
                            when "add_node_with_password"
                                add_node_with_password(**arguments)
                            when "add_node_with_private_key"
                                add_node_with_private_key(**arguments)
                            when "connect_node"
                                connect_node(**arguments)
                            when "disconnect_node"
                                disconnect_node(**arguments)
                            when "run_command_in_node"
                                run_command_in_node(**arguments)
                            when "reboot_node"
                                reboot_node(**arguments)
                            ## Browsers Operation
                            when "browser_start"
                                BlackStack::Jarvis::Browsing.start(**arguments)
                            when "browser_stop"
                                BlackStack::Jarvis::Browsing.stop(**arguments)
                            when "is_running"
                                BlackStack::Jarvis::Browsing.is_running?(**arguments)
                            when "visit"
                                BlackStack::Jarvis::Browsing.visit(**arguments)
                            when "scroll_horizontally"
                                BlackStack::Jarvis::Browsing.scroll_horizontally(**arguments)
                            when "scroll_vertically"
                                BlackStack::Jarvis::Browsing.scroll_vertically(**arguments)
                            when "take_screenshot"
                                BlackStack::Jarvis::Browsing.take_screenshot(**arguments)
                            when "click"
                                BlackStack::Jarvis::Browsing.click(**arguments)
                            else
                                raise "Unknown function name: #{function_name}"
                            end
                    
                            { tool_call_id: tool['id'], output: tool_output.to_s }
                        rescue => e
puts e.to_console.red
                            { tool_call_id: tool['id'], output: "Error: #{e.message}" }
                        end
                    }
                    @@openai_client.runs.submit_tool_outputs(
                        thread_id: @@openai_thread_id, 
                        run_id: run_id, 
                        parameters: { tool_outputs: my_tool_outputs }
                    )
                when 'cancelled', 'failed', 'expired'
                    raise response['last_error']['message']
                    break # or `exit`
                else
                    raise "Unknown run status response from OpenAI: #{status}"
                end
            end

            # 
            messages = @@openai_client.messages.list(thread_id: @@openai_thread_id) 
            messages['data'].first['content'].first['text']['value']
        end # def chat

        def console
            puts "Jarvis Console".blue
            puts "Type 'exit' to quit.".blue
            while true
                print "You: ".green
                prompt = gets.chomp
                break if prompt == 'exit'
                begin
                    puts "Jarvis: #{chat(prompt)}".blue
                rescue => e
                    puts "Error: #{e.message}".red
                    puts e.to_console
                end
            end
        end # def console

    end # class Jarvis
end # module BlackStack