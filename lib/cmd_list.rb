require_relative 'zapbot_base.rb'

class ZapBot::CommandList

    def initialize with_commands = nil
        @commands = {}

        if with_commands
            add with_commands
        end
    end

    def has_command? command_name
        @commands.key? command_name
    end

    def aliases_for_command command
        command_name = if command.is_a? String
            command
        else
            command.name
        end

        if has_command? command_name
            @commands.select do |name, cmd|
                cmd.is_alias_for? command_name
            end
        else
            {}
        end
    end

    def get_command command
        command_name = if command.is_a? String
            command
        else
            command.name
        end

        @commands[command_name]
    end

    def commands
        @commands.values
    end

    def commands_without_aliases
        @commands.values.reject { |cmd| cmd.is_alias? }
    end

    def command_names
        @commands.keys
    end

    def command_names_without_aliases
        @commands.keys.reject { |cmd| @commands[cmd].is_alias? }
    end

    def add commands
        if commands.is_a? Hash
            commands.each do |name, command|
                @commands[name] = command
            end
        elsif commands.is_a? Array
            commands.each do |command|
                @commands[command.name] = command
            end
        # Given data is actually a single command instead of a group.
        else
            @commands[commands.name] = commands
        end
    end

    def remove command
        old_command_name = if command.is_a? String
            command
        else
            command.name
        end

        # Get first alias and replace all alias references of command to
        # be deleted with the name of the first found alias.
        first_alias = @commands.values.find do |cmd|
            cmd.is_alias_for? old_command_name
        end

        unless first_alias.nil?
            change_aliases_of old_command_name, first_alias.name
        end

        @commands.delete old_command_name
    end

    def change_name_of command, new_name
        old_name = if command.is_a? String
            command
        else
            command.name
        end
        
        @commands[new_name] = @commands.delete old_name
        
        # Change any aliases of old command to refer to new command name if
        # command is not an alias.
        unless @commands[new_name].is_alias?
            change_aliases_of @commands[new_name], new_name
        end
    end

    private
    def change_aliases_of command, new_name
        old_name = if command.is_a? String
            command
        else
            command.name
        end

        @commands.values.each do |cmd|
            if cmd.is_alias_for? old_name
                cmd.set_as_alias_of new_name
            end
        end
    end
end
