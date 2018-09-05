require 'discordrb'
require_relative 'command.rb'
require_relative 'cmd_list.rb'

module ZapBot::CommandContainer
    attr_reader :commands

    def command(name, **attributes, &block)
        @commands ||= ZapBot::CommandList.new

        if name.is_a? Array
            name.map! &:downcase
            main_name = name.first

            new_command = ZapBot::Command.new(main_name.to_s, **attributes, &block)
            @commands.add new_command

            alias_names = name[1..-1]

            # Change attributes for aliases
            attributes[:display_in_help?] = false
            attributes[:aliased_command] ||= main_name

            alias_names.each do |a_n|
                new_command = ZapBot::Command.new(a_n.to_s, **attributes, &block)
                @commands.add new_command
            end

            return new_command
        else
            name = name.downcase
            new_command = ZapBot::Command.new(name.to_s, **attributes, &block)
            @commands.add new_command
        end

        return new_command
    end

    def extend command_container
        @commands.add command_container.commands
    end
end
