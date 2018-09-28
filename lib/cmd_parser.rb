require_relative 'zapbot_base.rb'

module ZapBot::CommandParsing

    def self.filter_help_vars! text
        text.gsub! /\$<PREFIX>|\$<PFX>/,  "<%= help[:prefix] %>"
        text.gsub! /\$PREFIX|$PFX/, "help[:prefix]"
        text.gsub! /\$<COMMAND>|\$<CMD>/, "<%= help[:command] %>"
        text.gsub! /\$COMMAND|\$CMD/, "help[:command]"
        text.gsub! /\$<NAME>/, "<%= help[:name] %>"
        text.gsub! /\$NAME/, "help[:name]"
        text.gsub! /\$<DESCRIPTION>|\$<DESC>/,  "<%= help[:description] %>"
        text.gsub! /\$DESCRIPTION|\$DESC/, "help[:description]"
        text.gsub! /\$<EXAMPLES>|\$<EX>/, "<%= help[:examples] %>"
        text.gsub! /\$EXAMPLES|\$EX/, "help[:examples]"
        text.gsub! /\$<ALIASES>|\$<AL>/, "<%= help[:aliases] %>"
        text.gsub! /\$ALIASES|\$AL/, "help[:aliases]"
        text.gsub! /\$<USAGE>|\$<USE>/, "<%= help[:usage] %>"
        text.gsub! /\$USAGE|\$USE/, "help[:usage]"
    end

    def self.is_float? text
        true if Float(text) rescue false
    end

    def self.is_int? text
        true if Integer(text) rescue false
    end

    def self.find_prefix with_prefix_list, text
        possible_prefixes = with_prefix_list.find_all do |prefix|
            text.downcase.start_with? prefix
        end
        possible_prefixes.max_by &:length
    end

    def self.find_command with_command_list, text
        possible_commands = with_command_list.select do |command|
            text.downcase.start_with? command.name
        end

        # Get all command names and return longest matching name in list.
        possible_command_names = possible_commands.map { |c| c.name }
        possible_command_names.max_by &:length
    end

    def self.argsplit with_text
        scanner = StringScanner.new with_text
        items = []

        until scanner.eos?
            # Grab any text, or quoted string (with optional -- at beginning)
            items.push scanner.scan /(--)?".*?"|\S+/
            # Grab any whitespace to throw away before next item scan.
            scanner.scan /\s+/
        end

        return items
    end

    CommandArg = Struct.new :type, :value
    def self.typify arg
        if is_int? arg
            CommandArg.new(type=:int, value=arg.to_i)
        elsif is_float? arg
            CommandArg.new(type=:float, value=arg.to_f)
        # If arg is surrounded by quotes, it's a string.
        elsif arg[0] + arg[-1] == '""'
            CommandArg.new(type=:string, value=arg[1...-1])
        # If arg starts with '--', it's a flag.
        elsif arg.start_with? '--'
            if arg[2] + arg[-1] == '""'
                CommandArg.new(type=:flag, value=arg[3...-1])
            else
                CommandArg.new(type=:flag, value=arg[2..-1])
            end
        else
            CommandArg.new(type=:word, value=arg)
        end
    end

    def self.typify_all args
        args.map { |arg| typify arg }
    end

    def self.split_args_and_flags typed_args
        inputs = { :args => [], :flags => [] }

        typed_args.each do |arg|
            if arg.type == :flag
                inputs[:flags].push arg
            else
                inputs[:args].push arg
            end
        end

        return inputs
    end

    # TODO: Do this function; take event and create context object.
    def self.create_context_from event
    end

    def self.grab_arg_of_type_in arg_list, wanted_types
        result = nil

        until !result.nil? || wanted_types.empty?
            wanted_type = wanted_types.shift
            arg_index = arg_list.find_index do |arg|
                arg.type == wanted_type
            end

            unless arg_index.nil?
                result = arg_list[arg_index]
                arg_list.delete_at arg_index
            end
        end

        if result.nil?
            # TODO: Raise error here.
        end

        return result
    end

    def self.order_args params, arg_types, bot, context, event
        current_args = arg_types[:args].clone
        ordered_args = []
        arg_to_add = nil
        arg_index = nil
        extras_arg_marker = :__EXTRAS__

        params.each do |param_name, param_type|
            case param_type
            # Arg type that will accept any non-flag input.
            when :any
                # Since type is not known when given to command, convert arg
                # back to string if needed so 'any' args at least start
                # with consistent type.
                arg_to_add = current_args.first.value.to_s
                current_args.delete_at 0
            # Arg type that gives the raw text of everything after the
            # command. Good for if you want the command to work with the
            # exact, unfiltered text typed in it.
            when :glob
                arg_to_add = arg_types[:raw_text]
            # Arg type that gives the command's args as a simple array
            # of strings; different than 'glob' type in that the array
            # will have processed out whitespace between args, while the
            # arg text glob will have no processing.
            when :raw_args
                arg_to_add = arg_types[:raw_args]
            # Arg type that gives the array of CommandArgs objects that
            # note the type and value of each arg; useful if a command
            # wants to do some different processing with the args based
            # on type.
            when :typed_args
                arg_to_add = arg_types[:args]
            # Returns the list of all args, but only the values.
            when :args
                arg_to_add = arg_types[:args].map { |arg| arg.value }
            # Like 'typed_args', but for flags.
            when :typed_flags
                arg_to_add = arg_types[:flags]
            # Like 'args', but returns all the flag values.
            when :flags
                arg_to_add = arg_types[:flags].map { |flag| flag.value }
            # Arg type that returns any args not added to the arg list.
            when :extras
                # arg_to_add = current_args.clone
                arg_to_add = extras_arg_marker
            when :int
                found_arg = grab_arg_of_type_in(
                    current_args, wanted_types = [:int, :float]
                )
                # Floats may be used as a substitute if no ints are found.
                if found_arg.is_a? Float
                    found_arg = found_arg.to_i
                end

                arg_to_add = found_arg&.value
            when :float, :number
                found_arg = grab_arg_of_type_in(
                    current_args, wanted_types = [:float, :int]
                )

                if found_arg.is_a? Integer
                    found_arg = found_arg.to_f
                end

                arg_to_add = found_arg&.value
            when :word
                found_arg = grab_arg_of_type_in(
                    current_args, wanted_types = [:word]
                )
                arg_to_add = found_arg&.value
            when :string
                found_arg = grab_arg_of_type_in(
                    current_args, wanted_types = [:string, :word]
                )

                arg_to_add = found_arg&.value
            when :bot
                arg_to_add = bot
            when :utils
                arg_to_add = bot.utils
            when :context
                arg_to_add = context
            when :event
                arg_to_add = event
            when :message
                arg_to_add = context.message
            when :author
                arg_to_add = context.author
            when :channel
                arg_to_add = context.channel
            when :server
                arg_to_add = context.server
            when :file
                arg_to_add = context.file
            when :timestamp
                arg_to_add = context.timestamp
            end

            ordered_args.push arg_to_add
        end

        # Look through ordered args and replace any args denoted as an
        # 'extras' arg with the actual extra arguments.
        ordered_args.map! do |arg|
            if arg == extras_arg_marker
                current_args.clone
            else
                arg
            end
        end

        # If any nil args are at the end, remove them.
        # This will allow commands to have the potential for default
        # parameter values as if nothing is found for the arg, then
        # nothing really will be given to the function.
        while !ordered_args.empty? && ordered_args.last.nil?
            ordered_args.pop
        end

        return ordered_args
    end

    # Looks at a command, and some given arguments, and arranges together
    # a function call to evaluate that has a smart ordering of the arguments
    # so that any optional parameters that are not supplied an argument can
    # be given nothing while other parameters are given arguments.
    def self.evaluate_command command, *args
        param_signature = command.func.parameters
        arg_text = []
        arg_index = 0

        param_signature.each do |signature|
            arg_required = signature[0] == :req
            param_name = signature[1]

            arg = args[arg_index]

            if arg_required
                if arg.nil?
                    # TODO: Raise error here.
                else
                    arg_text.push "#{param_name} = args[#{arg_index}]"
                end
            else
                unless arg.nil?
                    arg_text.push "#{param_name} = args[#{arg_index}]"
                end
            end
            arg_index += 1
        end

        eval <<-EVAL, binding, __FILE__, __LINE__ + 1
            command.func.call(#{arg_text.join ', '})
        EVAL
    end
end
