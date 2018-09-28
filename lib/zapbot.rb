require 'discordrb'
require 'tomlrb'
require 'erb'
require_relative 'config_loader.rb'
require_relative 'command.rb'
require_relative 'cmd_context.rb'
require_relative 'cmd_parser.rb'
require_relative 'cmd_container.rb'
require_relative 'cmd_list.rb'
require_relative 'main_cmd_list.rb'
require_relative 'bot_utils.rb'
require_relative 'menu.rb'

# TODO: Redo command executing algorithm to work with command parser changes,
#       allow multiple command runs, and other special things.
# TODO: Add Rdoc or something

# TODO: Convert the config files from TOML to YAML
#       TOML doesn't look much better, and YAML won't need the user to do
#       a wonky conversion for command names with spaces.
module ZapBot
    
    class ZapBot < Discordrb::Bot
        attr_accessor :helpdoc_path, :config_path, :config, :data, :prefixes
        attr_reader(
            :commands, :command_list, :utils, :token, :client_id
        )

        def initialize(attributes = {})
            # Set attributes for file paths for bot configuration and
            # documentation files.
            # TODO: Change default bot paths
            @config_path = attributes[:config_path] || 'bot_config.toml'
            @helpdoc_path = attributes[:helpdoc_path] || 'help_docs/'
            @helpformat_file = attributes[:helpformat_file] || 'format.toml'

            data = ConfigLoader.load_config_data @config_path
            @prefixes = data.prefixes

            # Set default attributes.
            super(
                log_mode: attributes[:log_mode],
                token: data.token,
                client_id: data.client_id,
                type: attributes[:type],
                name: attributes[:name],
                fancy_log: attributes[:fancy_log],
                suppress_ready: attributes[:suppress_ready],
                parse_self: attributes[:parse_self],
                shard_id: attributes[:shard_id],
                num_shards: attributes[:num_shards],
                redact_token: attributes.key?(:redact_token) ? attributes[:redact_token] : true,
                ignore_bots: attributes[:ignore_bots]
            )

            @command_list = MainCommandList.new with_bot = self
            @utils = BotUtils.new with_bot = self, data.colors
        end

        def include_commands! command_container, in_cog
            @command_list.insert_into_cog command_container.commands, in_cog
        end

        def help_for command, **help
            config_filepath = @helpdoc_path + "#{command.cog.downcase}.toml"
            config = Tomlrb.load_file(config_filepath, symbolize_keys: true)
            command_symbol = command.name.gsub(/\s+/, '_').downcase.to_sym
            command_help = config[command_symbol]
            data = command_help.nil?? nil \
                    : ConfigLoader::ZapBotHelpData.new

            unless data.nil?
                data.description = config.dig(command_symbol, :description)

                unless data.description.nil?
                    CommandParsing.filter_help_vars! data.description
                    data.description = ERB.new(data.description).result binding
                end

                data.usage = config.dig(command_symbol, :usage)

                unless data.usage.nil?
                    CommandParsing.filter_help_vars! data.usage
                    data.usage = ERB.new(data.usage).result binding
                end

                data.examples = config.dig(command_symbol, :examples)

                unless data.examples.nil?
                    CommandParsing.filter_help_vars! data.examples
                    data.examples = ERB.new(data.examples).result binding
                end
            end

            return data
        end

        def help_format format_type
            config = Tomlrb.load_file(
                @helpdoc_path + @helpformat_file, symbolize_keys: true
            )
            format = config[format_type]

            unless format.nil?
                format = format[:format]
            end

            return format
        end

        def help_format_fill format_text, **help
            result = nil

            unless format_text.nil?
                CommandParsing.filter_help_vars! format_text
                template = ERB.new format_text
                result = template.result(binding)
            end

            return result
        end

        def execute_command event
            text = event.message.content.strip
            prefix = CommandParsing.find_prefix @prefixes, text

            unless prefix.nil?
                # Remove prefix from text
                text = text[prefix.length..-1].strip
                command_name = CommandParsing.find_command(
                    @command_list.all.commands, text
                )

                unless command_name.nil?
                    command = @command_list.all.get_command command_name

                    command_context = CommandContext.new(with_attributes = {
                        :bot                => self,
                        :author             => event.author,
                        :message            => event.message,
                        :channel            => event.channel,
                        :server             => event.server,
                        :file               => event.file,
                        :timestamp          => event.timestamp,
                        :event              => event,
                        :prefix             => prefix,
                        :root_command       => command,
                        :in_command_chain   => false
                    })
                    # Remove command name from text, leaving on raw args
                    text = text[command_name.length..-1].strip
                    raw_args = CommandParsing.argsplit text
                    typed_args = CommandParsing.typify_all raw_args
                    command_inputs = CommandParsing.split_args_and_flags(
                        typed_args
                    )
                    arg_types = {
                        :raw_text   => text.empty?? nil : text,
                        :raw_args   => raw_args,
                        :args       => command_inputs[:args],
                        :flags      => command_inputs[:flags]
                    }
                    ordered_args = CommandParsing.order_args(
                        params      = command.params,
                        arg_types   = arg_types,
                        bot         = self,
                        context     = command_context,
                        event       = event
                    )
                    # command_result = command.execute *ordered_args
                    command_result = CommandParsing.evaluate_command(
                        command, *ordered_args
                    )

                    # TODO: Add a loop and whatnot for subcommands and
                    #       additional commands.
                    if command.say_result? && !command_result.nil?

                        # Returned hashes are interpreted as data to
                        # put into an embedded message.
                        if command_result.class == Hash

                            embed_desc_too_big = command_result[:desc] && \
                                    command_result[:desc].to_s.length > 2048
                            
                            # If embed description text is too long, break
                            # it up into multiple embeds posted in sequence.
                            if embed_desc_too_big
                                chunk_start = 0
                                chunk_end = 2047
                                count = 1
                                desc = command_result[:desc].to_s
                                title = command_result[:title].to_s
                                
                                while chunk_start < desc.length
                                    current_desc = desc[chunk_start..chunk_end]
                                    current_title = title + " [ #{count} ]"
                                    command_result[:desc] = current_desc
                                    command_result[:title] = current_title

                                    @utils.send_from_payload event.channel, command_result
                                    #send_result_embed command_result, event

                                    chunk_start += 2048
                                    chunk_end += 2048
                                    count += 1
                                end
                            else
                                @utils.send_from_payload(
                                    event.channel, command_result
                                )
                            end
                        elsif command_result.class == File
                            send_file(event.channel, command_result)
                        else
                            send_message(event.channel, command_result.to_s)
                        end
                    end
                end
            end
        end

        private

        def send_result_embed(with_result, event)
            result_embed = @utils.hash_to_embed with_result

            event.channel.send_file(

            ) if with_result.dig(:file, :position) == :before

            event.channel.send_message(
                with_result[:content] || '',
                with_result[:tts] || false,
                result_embed
            )
        end
    end
end
