require_relative 'zapbot_base.rb'

class ZapBot::CommandContext

    attr_reader(
        :bot, :author, :message, :channel, :server, :file, :timestamp,
        :event, :prefix, :root_command, :in_command_chain
    )

    def initialize with_attributes = {}
        with_attributes.each do |name, value|
            self.send("#{name}=", value)
        end
    end

    def set_attributes with_attributes
        with_attributes.each do |name, value|
            self.send("#{name}=", value)
        end
    end

    private
    attr_writer(
        :bot, :author, :message, :channel, :server, :file, :timestamp,
        :event, :prefix, :root_command, :in_command_chain
    )
end
