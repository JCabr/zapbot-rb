require 'discordrb'
require 'English'
require_relative 'zapbot_base.rb'

class ZapBot::BotUtils

    attr_reader :colors

    @@mention_regex = /^<(?<symbol>@[!&]?|#|:.+?:)(?<id>\d{18})>$/

    def initialize with_bot, colors = nil
        @bot = with_bot
        @colors = if colors.nil? then {} else colors end
    end

    # Convenience method that allows getting colors in a more readable way.
    def get_color name
        @colors[name]
    end

    alias :get_color_for :get_color
    alias :get_colour :get_color
    alias :get_colour_for :get_color

    def insert_color name, color_hex
        @colors[name] = color_hex
    end

    alias :insert_colour :insert_color

    def delete_color name
        @colors.delete name
    end

    alias :delete_colour :delete_color

    MentionParseResult = Struct.new :type, :id, :symbol
    def parse_for_mention text
        mention_match = @@mention_regex.match text
        result = nil

        if @@mention_regex.match text
            symbol = $LAST_MATCH_INFO['symbol']
            id = $LAST_MATCH_INFO['id'].to_i
            type = nil

            case symbol
            when '#'
                type = :channel
            when '@&'
                type = :role
            when /@[!]?/
                type = :member
            when /:.+?:/
                type = :emoji
            end

            result = MentionParseResult.new(type, id, symbol)
        end

        return result
    end

    # TODO: Make this take a string for a mention (or a MentionParseResult)
    #       and, based on its mention type, convert it to the proper
    #       discord object like User/Member, Role, Channel, etc.
    def convert_mention mention, server, mask_everyone_role = true
        result = nil

        if mention.is_a? MentionParseResult then
            case mention.type
            when :channel
                result = server.channels.select do |channel|
                    channel.id == mention.id
                end.first
            when :member
                result = server.member mention.id
            when :role
                result = server.role mention.id

                if mask_everyone_role && result == server.everyone_role
                    result = :everyone_role
                end
            when :emoji
                result = server.emojis[mention.id]
            end
        elsif !mention.nil?
            result = convert_mention(parse_for_mention(mention), server)
        end

        return result
    end

    def is_mention? text
        return text =~ @@mention_regex
    end

    def get_member_color with_id, server, to_hex = true
        with_id = if with_id.is_a? String
            with_id.to_i
        else
            with_id
        end
        
        member = server.member with_id
        color = nil

        unless member.nil?
            color = member.color

            if to_hex
                color = color.hex
            end
        end

        return color
    end

    alias :get_member_colour :get_member_color
end
