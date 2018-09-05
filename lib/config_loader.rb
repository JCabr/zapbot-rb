require 'tomlrb'
require_relative 'zapbot_base.rb'

module ZapBot::ConfigLoader

    class ZapBotData
        attr_accessor :prefixes, :token, :client_id, :colors, :settings

        ZapBotSettings = Struct.new(
            :case_insensitive_prefixes,
            :exclusive_prefixes,
            :enforced_typing,
            :enforced_order,
            :smart_typing,
            :iterative_chaining,
            :recursive_chaining
        )

        def initialize
            @settings = ZapBotSettings.new(
                true,
                false,
                true,
                false,
                true,
                true,
                true
            )
        end

        def update_bot_settings with_settings_hash
            with_settings_hash.each { |k, v| @settings.send("#{k.to_s}=", v) }
        end
    end

    def self.load_config_data with_config_path
        config = Tomlrb.load_file with_config_path, symbolize_keys: true
        data = ZapBotData.new
        botdata = config[:botdata]

        data.token = botdata[:token]
        data.client_id = botdata[:client_id]
        data.prefixes = botdata[:prefixes]
        data.colors = config[:colors] || config[:colours]
        puts data.colors.inspect

        data.update_bot_settings config[:settings]
        return data
    end

    class ZapBotHelpData
        attr_accessor :description, :usage, :examples
    end
end
