require 'discordrb'
require 'English'
require_relative 'zapbot_base.rb'
require_relative 'menu.rb'

class ZapBot::BotUtils
    attr_reader :colors

    @@mention_regex = /^<(?<symbol>@[!&]?|#|:.+?:)(?<id>\d{18})>$/

    def initialize(with_bot, colors = nil)
        @bot = with_bot
        @colors = colors.nil? ? {} : colors
    end

    # TODO: Maybe add :middle position option for files that will put the
    #       file between the message text and the embed.
    #       This could be accomplished by sending two separate messages
    #       for the content and the embed, and sending the file message
    #       between them.
    MessagesFromHash = Struct.new(:file_message, :main_message)
    def send_from_payload(channel, message_hash)
        content = message_hash[:content].nil? ? '' : message_hash[:content]
        embed = message_hash[:embed]
        file = message_hash[:file]
        tts = message_hash[:tts] || false

        send_out_file = lambda {
            file_data =
                if file[:object].nil?
                    File.open file[:path], 'r'
                else
                    file[:object]
                end

            file_tts = file[:tts] || false
            channel.send_file(
                file_data, caption: file[:caption], tts: file_tts
            )
        }

        embed = hash_to_embed(message_hash[:embed]) unless embed.nil?

        f = nil

        f = send_out_file[] unless file.nil? || file[:position] != :before

        m = channel.send_message(content, tts, embed) if content != '' || embed

        f = send_out_file[] unless file.nil? || file[:position] != :after

        return MessagesFromHash.new(f, m)
    end

    # TODO: Add support for author (EmbedAuthor) item, and a list of EmbedFields.
    def hash_to_embed(embed_hash)
        title = embed_hash[:title]
        title = title.call() if title.respond_to?(:call)

        desc = embed_hash[:desc] || embed_hash[:description]
        desc = desc.call() if desc.respond_to?(:call)

        color = embed_hash[:color] || embed_hash[:colour]
        color = color.call() if color.respond_to?(:call)
        color = color.to_i(16) if color.is_a? String
        color = get_color(color) if color.is_a? Symbol

        footer_text = embed_hash.dig(:footer, :text)
        footer_text = footer_text.call() if color.respond_to?(:call)
        footer_url = embed_hash.dig(:footer, :icon_url)
        footer_url = footer_url.call() if footer_url.respond_to?(:call)

        image_url = embed_hash[:image_url]
        image_url = image_url.call() if image_url.respond_to?(:call)

        thumbnail_url = embed_hash[:thumbnail_url]
        thumbnail_url = thumbnail_url.call() if thumbnail_url.respond_to?(:call)

        timestamp = embed_hash[:timestamp]
        timestamp = timestamp.call() if timestamp.respond_to?(:call)

        url = embed_hash[:url]
        url = url.call() if url.respond_to?(:call)

        return Discordrb::Webhooks::Embed.new(
            title: title,
            description: desc,
            color: color,
            footer: Discordrb::Webhooks::EmbedFooter.new(
                text: footer_text,
                icon_url: footer_url
            ),
            image: Discordrb::Webhooks::EmbedImage.new(
                url: image_url
            ),
            thumbnail: Discordrb::Webhooks::EmbedThumbnail.new(
                url: thumbnail_url
            ),
            timestamp: timestamp,
            url: url
        )
    end

    def send_animated_message(
        channel, interval, frames, repeat = false, repititions = 1
    )
        start_frame = frames.first
        other_frames = frames[1..-1]

        display_frame = lambda { |frame, mode, message = nil|
            content = frame[:content].nil? ? '' : frame[:content]
            tts = frame[:tts].nil? ? false : frame[:tts]
            embed = hash_to_embed frame[:embed]

            frame_message =
                if mode == :send
                    channel.send_message(content, tts, embed)
                else
                    message.edit(content, embed)
                end

            return frame_message
        }

        frame_message = display_frame[start_frame, :send]

        other_frames.each do |frame|
            sleep(interval)
            frame_message = display_frame[frame, :edit, frame_message]
        end

        return frame_message unless repeat

        repititions.times do
            frames.each do |frame|
                sleep(interval)
                frame_message = display_frame[frame, :edit, frame_message]
            end
        end

        return frame_message
    end

    def make_menu(context, startpage = :start, *pages)
        menu = ZapBot::Menu.new context, @bot, startpage

        return menu if pages.empty?

        menu.add_pages(*pages)
        return menu
    end

    # Convenience method that allows getting colors in a more readable way.
    def get_color(name)
        @colors[name]
    end

    alias get_color_for get_color
    alias get_colour get_color
    alias get_colour_for get_color

    def insert_color(name, color_hex)
        @colors[name] = color_hex
    end

    alias insert_colour insert_color

    def delete_color(name)
        @colors.delete name
    end

    alias delete_colour delete_color

    def shown_name_for(user)
        if user.respond_to? :display_name
            user.display_name
        else
            user.username
        end
    end

    MentionParseResult = Struct.new :type, :id, :symbol
    def parse_for_mention(text)
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
    def convert_mention(mention, server, mask_everyone_role = true)
        result = nil

        if mention.is_a? MentionParseResult
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

    def is_mention?(text)
        return text =~ @@mention_regex
    end

    def get_member_color(with_id, server, to_hex = true)
        with_id =
            if with_id.is_a? String
                with_id.to_i
            else
                with_id
            end

        member = server.member with_id
        color = nil

        unless member.nil?
            color = member.color
            color = color.hex if to_hex
        end

        return color
    end

    alias get_member_colour get_member_color
end
