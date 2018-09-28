# frozen_string_literal: true

require_relative 'zapbot_base.rb'

# Doc
class ZapBot::Menu
    MenuPage = Struct.new(
        :name, :message, :timeout, :on_response, :on_timeout, :tts
    )
    attr_reader :pages, :current_page, :current_page_message, :variables

    def initialize(context, bot, startpage = :start)
        @context = context
        @pages = {}
        @current_page = nil
        @current_page_message = nil
        @bot = bot
        @variables = {}
        @startpage = startpage
    end

    def var
        @variables
    end

    def add_variable(id, value)
        @variables[id] = value
    end

    alias add_var add_variable

    def get_variable(id)
        @variables[id]
    end

    alias get_var get_variable

    alias set_variable add_variable

    def remove_variable(id)
        @variables.delete id
    end

    alias remove_var remove_variable

    def add_page(
        name:, message: nil, timeout: nil, on_response: nil,
        on_timeout: nil
    )
        @pages[name] = MenuPage.new(
            name, message, timeout, on_response, on_timeout
        )
    end

    def add_pages(*pages)
        pages.each do |page|
            add_page(**page)
        end
    end

    def delete_current_page_message() end

    def start
        message_page(@startpage)
    end

    def edit_to_page(id) end

    def message_page(id)
        page = @pages[id]

        if id.nil?
            raise ArgumentError, "Menu page with id \"#{id}\" does not exist"
        end

        # TODO: Change this just to send the message in bulk as a hash.
        #       Also rework the rest of the function.
        send_page = lambda { |channel, message_data|
            @bot.utils.send_from_payload(channel, message_data)
            # channel.send_message(content, tts, embed)
        }.curry.(@context.channel)

        sent_page = send_page[page.message]

        @current_page = page
        @current_page_message = sent_page

        return if page.timeout.nil?

        # We have to hack in awaiting a message within a timeout because
        # the standard Discordrb::Message.await! isn't able to properly
        # detect responses in the context of this function running in a
        # command (it just sits there until the timeout and returns nil).
        # However, standard message events do work, so that's used to
        # generally replicate the functionality for this instance.
        responded = false

        temp_handler = @bot.message(
            from: @context.author,
            in: @context.channel
        ) do |response_event|
            responded = true
            @bot.remove_handler temp_handler
            page&.on_response&.call(response_event)
        end

        sleep page.timeout
        @bot.remove_handler(temp_handler) unless responded

        !responded && page.on_timeout.call() if page.on_timeout
    end
end
