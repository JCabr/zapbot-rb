# frozen_string_literal: true

Gem::Specification.new do |spec|
    spec.name           = 'zapbot'
    spec.version        = '0.0.0'
    spec.authors        = ['JCabr']
    spec.email          = ['']
    spec.summary        = 'Wrapper over Discord.rb'
    spec.description    = "A Discord bot library that wraps over
                           Discord.rb's Bot to make a bot framework
                           that is more convenient to use for general
                           bot creation.".split.join()

    spec.files = [
        'lib/bot_utils.rb',
        'lib/cmd_container.rb',
        'lib/cmd_context.rb',
        'lib/cmd_list.rb',
        'lib/cmd_parser.rb',
        'lib/command.rb',
        'lib/config_loader.rb',
        'lib/main_cmd_list.rb',
        'lib/menu.rb',
        'lib/zapbot_base.rb',
        'lib/zapbot.rb'
    ]
    spec.require_paths  = ['lib']
    spec.license        = 'MIT'
end
