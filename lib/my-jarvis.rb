
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
    
        # {'label' => 'foo', 'node' => <bBlackStack::Infrastructure::Node object here> }
        @@nodes = []

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
            @@adspower_api_key = h[:adspower_api_key] if h[:adspower_api_key]

            # dropbox
            @@dropbox_refresh_token = h[:dropbox_refresh_token] if h[:dropbox_refresh_token]
        end

        # for internal use only
        def run_command_in_local_computer(command:)
            ret = `#{command}`
            ret
        end  
        
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
        def add_node_with_password(label, net_remote_ip, ssh_port, ssh_username, ssh_password)
            raise 'Already exists a node with this label.' if @@nodes.find { |n| n['label'] == label }
            node = BlackStack::Infrastructure::Node.new(
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
        def connect_node(label)
            node = @@nodes.find { |n| n['label'] == label }
            raise "Node not found." if node.nil?
            node['node'].connect
        end

        # disconnect from a node via ssh.
        def disconnect_node(label)
            node = @@nodes.find { |n| n['label'] == label }
            raise "Node not found." if node.nil?
            node['node'].disconnect
        end

        # run a command in a node via ssh.
        def run_command_in_node(label, command)
            node = @@nodes.find { |n| n['label'] == label }
            raise "Node not found." if node.nil?
            node.exec(command)
        end

        # reboot a node via ssh.
        def reboot_node(label)
            node = @@nodes.find { |n| n['label'] == label }
            raise "Node not found." if node.nil?
            node.reboot
        end

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
                        
                        tool_output = case function_name
                        when "run_command_in_local_computer"
                            run_command_in_local_computer(**arguments)
                        when "nodes"
                            nodes
                        when "add_node_with_password"
                            add_node_with_password(**arguments)
                        when "add_node_with_private_key"
#binding.pry
# Agrega este nodo a tu lista porvaor: mp01. ip: 3.15.213.149. puerto: 22, usuario: ubuntu, la clave ssh esta en el archivo ~/code/massprospecting/cli/mp.pem en la computadora local.
                            add_node_with_private_key(**arguments)
                        when "connect_node"
                            connect_node(**arguments)
                        when "disconnect_node"
                            disconnect_node(**arguments)
                        when "run_command_in_node"
                            run_command_in_node(**arguments)
                        when "reboot_node"
                            reboot_node(**arguments)
                        else
                            raise "Unknown function name: #{function_name}"
                        end
                
                        { tool_call_id: tool['id'], output: tool_output }
                    }
binding.pry
                    @@openai_client.runs.submit_tool_outputs(thread_id: @@openai_thread_id, run_id: run_id, parameters: { tool_outputs: my_tool_outputs })
                when 'cancelled', 'failed', 'expired'
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