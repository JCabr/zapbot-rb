require 'active_support/all'
require_relative 'cmd_list.rb'

class ZapBot::MainCommandList

    attr_reader :all, :cogs

    def initialize with_bot
        @all = ZapBot::CommandList.new
        @cogs = {}
        @bot = with_bot
    end

    def has_command? command_name
        @all.has_command? command_name
    end

    def insert_into_cog command_list, cog_name
        command_list.commands.each do |command|
            command.cog = cog_name
        end

        @cogs[cog_name] ||= ZapBot::CommandList.new
        @cogs[cog_name].add command_list.commands
        @all.add command_list.commands
    end

    # TODO: Make this redirect aliases to the help for the command they
    #       are aliasing.
    def help_text_for_command command, context, &block
        command_name =
            if command.is_a? String
                command
            else
                command.name
            end

        help_text = nil

        command = @all.get_command command_name

        unless command.nil?
            help_text = ''

            # If command is an alias, change the command help is wanted for
            # to the command being aliased.
            if command.is_alias?
                command = @all.get_command command.aliased_command
                command_name = command.name
            end

            command_aliases = @all.aliases_for_command command_name
            command = @all.get_command command_name

            command_help = @bot.help_for(
                command,
                prefix: context.prefix,
                command: command_name
            )
            format_text = @bot.help_format :command

            desc = command_help&.description
            usage = command_help&.usage
            examples = command_help&.examples

            help_text = @bot.help_format_fill(
                format_text,
                description: desc,
                aliases: command_aliases.keys,
                name: command_name.titleize,
                usage: usage,
                examples: examples
            )
        end

        return help_text if block.nil?

        result = yield help_text
    end

    CogHelpText = Struct.new :name, :commands
    def command_help_list_by_cogs
        cog_info_text = []

        @cogs.each do |cog_name, _commands|
            cog_info_text.push(command_help_list_for_cog cog_name)
        end

        return cog_info_text
    end

    def command_help_list_for_cog(cog_name, &block)
        found_cog_name = @cogs.keys.find { |name| name.casecmp? cog_name }

        return nil if found_cog_name.nil?

        cog = @cogs[found_cog_name]

        commands_info = []
        command_list_format = @bot.help_format :list

        cog.commands.each do |command|
            next unless command.display_in_help?

            command_help = @bot.help_for command
            desc = command_help.nil? ? nil : command_help.description

            help_text = @bot.help_format_fill(
                command_list_format,
                description: desc,
                name: command.name
            )

            commands_info.push help_text
        end

        cog_info = CogHelpText.new(found_cog_name, commands_info)

        return cog_info if block.nil?

        result = yield cog_info
    end
end
