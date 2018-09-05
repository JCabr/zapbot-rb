require_relative 'zapbot_base.rb'

class ZapBot::Command
    
    attr_accessor(
        :func, :name, :params, :only_for, :description, :cog
    )
    # These attributes are most likely boolean attributes that will have
    # accessor methods written below so they can be accessed in a more
    # intuitive manner for ruby (with a ? to denote boolean values).
    attr_writer(
        :enforced_typing, :enforced_order, :smart_typing, :say_result,
        :display_in_help
    )
    attr_reader :aliased_command, :func

    def initialize(name, **attributes, &block)
        @name               = name
        @params             = attributes[:params] || {}
        @only_for           = attributes[:only_for] || {}
        @aliased_command    = attributes[:aliased_command] || nil
        @cog                = attributes[:cog]
        @enforced_typing    = if attributes[:enforced_typing?] == false
            false
        else
            true
        end
        # TODO: Remember what this even was for.
        @enforced_order     = if attributes[:enforced_order?] == false
            false
        else
            true
        end
        @smart_typing       = if attributes[:smart_typing?] == false
            false
        else
            true
        end
        @say_result         = if attributes[:say_result?] == false
            false
        else
            true
        end
        @display_in_help    = if attributes[:display_in_help?] == false
            false
        else
            true
        end
        @func               = block_to_lambda &block
        @description        = attributes[:description]
    end

    def is_alias_for? command
        if command.is_a? String
            @aliased_command == command
        else
            @aliased_command == command.name
        end
    end

    def is_alias?
        !(@aliased_command.nil?)
    end

    def remove_alias_status
        @aliased_command = nil
    end

    def set_as_alias_of command
        if command.is_a? String
            @aliased_command = command
        else
            @aliased_command = command.name
        end
    end

    def enforced_typing?; @enforced_typing end
    def enforced_order?; @enforced_order end
    def smart_typing?; @smart_typing end
    def say_result?; @say_result end
    def display_in_help?; @display_in_help end

    def execute *with_args
        @func.call *with_args
    end

    private
    def block_to_lambda &block
        obj = Object.new
        obj.define_singleton_method(:_, &block)
        return obj.method(:_).to_proc
    end
end
