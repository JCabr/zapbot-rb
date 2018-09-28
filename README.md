# Zapbot.rb

A Discord bot framework that wraps over Discordrb and its bot to make
creating bots simple, convenient, and as terse as it can be.

## Sections

- [Features](https://github.com/JCabr/zapbot-rb#features)
- [Dependencies](https://github.com/JCabr/zapbot-rb#dependencies)
- [Installation](https://github.com/JCabr/zapbot-rb#installation)
- [Usage](https://github.com/JCabr/zapbot-rb#usage)

## Features

- Uses a configuration file for bot data and settings, letting you keep
  the basic things out of your code.

- Extremely simple method for returning data to be sent from a command.
    - If you send a `File`, the file gets sent as a message.
    - If you send a `String`, or some other object, it gets sent as a string
      in a message
    - Sending a `Hash` lets you deeply customize the content to send, including
      embeds, such as: 
        ```rb
        return {
            content:            'Message text',
            embed:      {
                title:          'Embed title',
                description:    'Embed description'
            },
            file:       {
                caption:        'caption for file',
                path:           'filepath'
            }
        }
        ```
        This sends a message with the given content, embed, and file as
        you have described it.
    - There is a utility method to invoke this mid-command as well, so
      there should be little need to have to call a kind of `send_message`
      function ever.

- Smart command parsing algorithm allows you to specify the kind of arguments
  you want to be passed to your command function, allowing the command to
  ignore any unnecessary data given and not strictly rely on the order
  of arguments given to it.
    - Some example commands using this:
        ```rb
        command(
            name = 'add',
            params: {
                n1: :number,
                n2: :number
        }) do |n1, n2 = 0|
            "#{n1} + #{n2} = #{n1 + n2}"
        end
        ```
        The above command would run no matter what the given text is, as
        long as it's given at least one number.
        ```rb
        command(
            name = 'repeat',
            params: {
                text:   :string,
                times:  :number
        }) do |text, times|
            text * times
        end
        ```
        The above command will run if it is given a number and some text, and
        the order of the two arguments does not matter.

- The bot's command parsing allows you to essentially have anything in
  a command name or prefix, including whitespace. This makes English-like
  command invocations easy enough to use.

- It's simple to make help commands, as the bot has:
    - Utility methods for common help command operations.
        - Such as getting all the help text for all commands in a command
          group.
    - Built-in support for you storing the help text for commands in config
      files in a special help text directory.
        - Allows you to structure your bot project nicely.
        - You can also specify the general format for help text (both in
          an overall command list, or the full text when asked for help
          for a specific command) in a config file.
        - Anything relating to help text can have common variables (command
          name, prefix, portions of help text) in it,
          using ERB to fill the gaps.

- Useful utility methods to ensure your command code can be as short as
  possible, such as:
    - Support for making menus
        - Just give an id to each page in the menu, give the message that
          should be sent (using the same hash format shown above), procedures
          that should be run on a response/timeout if you want, a time limit,
          and all you'll need to do is call the method to start the menu in
          your command.
        - The menu object has methods that let you open pages and
          store/update/read variables specifically for the menu; the menu
          supports having its own state that you can use when designing it to
          ensure it allows you to make it as dynamic as you want.
        - You shouldn't need to write code with a bunch of conditions
          and waiting for responses from messages again.
    
    - Support for animated messages (as much as a rate limit will allow).
        - Can specify message content to send as frames.
        - If you only have a few frames you want repeated, you can specify
          that you want the overall animated repeated a certain amount.
    
    - Methods that allow you to check if text is a mention, and get the
      relevant information from it if it is.

- Since this library is just a wrapper over Discordrb's `Bot` object, you're
  still able to use pretty much everything from Discordrb if you'd like, and
  you'll still work with data types like `Discordrb::Message`, so any
  knowledge from using Discordrb will carry over.


## Dependencies

- [Discordrb](https://github.com/meew0/discordrb) and all its dependencies,
  which are listed as:
    - Ruby 2.2+
    - An installed build system for native extensions

## Installation

TODO

## Usage

Making a bot is fairly simple, and fairly similar to how making a command bot
in Discordrb works.

An example bot would be:
```rb
require 'zapbot'

bot = ZapBot::ZapBot.new(
    config_path:        "#{__dir__}/bot_config.yaml",
    helpdoc_path:       "#{__dir__}",
    helpformat_file:    "format.yaml"
)

module ExampleCommands
    extend ZapBot::CommandContainer

    command 'hi', params: { author: :author } do |author|
        "Hi there, #{author.display_name}!"
    end
end

bot.message do |event|
    event.bot.execute_command event
end

bot.include_commands! ExampleCommands, in_cog: 'Example Commands'

bot.run
```
