require "rubygems"
require "activesupport" # For the base extensions, we'll drop this later

module SVM
  class Function
    attr_reader :code, :return_type, :params, :vars, :name

    def initialize name, opts
      opts = opts.symbolize_keys
      @code = opts[:code].map{|op| (op.is_a?(Array) ? (op[0] = op.first.to_sym) : (op = op.to_sym)) ; op } 

      check(!opts[:return].nil?, "No return type specified")
      @return_type = opts[:return].to_sym

      @params = {} ; opts[:params].each{|k,v| @params[k.to_sym] = v.to_sym} if opts[:params]
      @vars = {} ; opts[:vars].each{|k,v| @vars[k.to_sym] = v.to_sym} if opts[:vars]

      check (@params.keys & @vars.keys).empty?, "Variables declared with the same names as parameters: #{(@params.keys & @vars.keys).inspect}"

      @name = name
    end

    def apply args={}
      check_params args
      locals = {} ; @vars.keys.each{|k| locals[k]=nil}
      locals = locals.merge args

      local_types = @params.merge @vars

      stack = []
      ret = nil
      pc = 0
      op = nil

      loop do
        inc = true # Whether to increment the PC this time
        check(pc >= 0 && pc < code.size, "Program counter out of bounds: #{pc}")

        op = code[pc]

        case (op.is_a?(Array) ? op.first : op)
          when :return
          ret = stack.pop
          break

          when :push
          stack.push op[1]

          when :dup
          stack.push stack.last

          when :load
          stack.push locals[op[1].to_sym]

          when :add
          a = stack.pop
          b = stack.pop
          check_numeric a, b
          stack.push a+b

          when :sub
          a = stack.pop
          b = stack.pop
          check_numeric a, b
          stack.push b-a

          when :mul
          a = stack.pop
          b = stack.pop
          check_numeric a, b
          stack.push a*b

          when :div
          a = stack.pop
          b = stack.pop
          check_numeric a, b
          stack.push b/a

          when :mod
          a = stack.pop
          b = stack.pop
          check_numeric a, b
          stack.push b%a

          when :store
          a = stack.pop
          name = op[1].to_sym
          type = local_types[name]
          check_type a, type, name
          locals[name] = a

          when :jmplt
          x = stack.pop
          y = stack.pop
          check_numeric x, y, op[1]
          if x<y
            inc = false
            pc = op[1]
          end

          when :jmpgt
          a = stack.pop
          b = stack.pop
          check_numeric a, b, op[1]
          if a>b
            inc = false
            pc = op[1]
          end

          when :jmple
          a = stack.pop
          b = stack.pop
          check_numeric a, b, op[1]
          if a<=b
            inc = false
            pc = op[1]
          end

          when :jmpge
          a = stack.pop
          b = stack.pop
          check_numeric a, b, op[1]
          if a>=b
            inc = false
            pc = op[1]
          end

          when :jmpz
          a = stack.pop
          check_numeric a, op[1]
          if a==0
            inc = false
            pc = op[1]
          end

          when :jmp
          check_numeric op[1]
          inc = false
          pc = op[1]

          when :dec
          a = stack.pop
          check_numeric a
          stack.push(a-1)

          when :inc
          a = stack.pop
          check_numeric a
          stack.push(a+1)

          when :size
          a = stack.pop
          check_array a
          stack.push a.size

          when :new_array
          stack.push []

          when :lookup
          a = stack.pop
          b = stack.pop
          check_array b
          check_numeric a
          stack.push b[a]

          when :array_set
          v = stack.pop
          i = stack.pop
          a = stack.pop
          check_numeric i
          check_array a
          a[i]=v

          when :array_append
          v = stack.pop
          a = stack.pop
          check_array a
          a << v

          when :new_hash
          stack.push Hash.new

          when :hash_set
          v = stack.pop
          k = stack.pop
          h = stack.pop
          check_hash h
          h[k]=v

          when :get
          k = stack.pop
          h = stack.pop
          check_hash h
          stack.push h[k]

          else
          check false, "Invalid opcode: #{op.inspect}"
        end

        pc += 1 if inc
      end

      ret
    rescue Error
      $!.stack = stack
      $!.pc = pc
      $!.opcode = op
      $!.locals = locals
      raise $!
    end

    def check_params args
      check((params.keys - args.keys).empty?, "Missing parameters: #{(params.keys - args.keys).inspect}")
      check((args.keys - params.keys).empty?, "Unexpected parameters: #{(args.keys - params.keys).inspect}")

      params.each do |name, type|
        check_type args[name], type, name
      end
    end

    def check_type value, type, name = "[unknown]"
      klass = case type
              when :number: Numeric
              when :string: String
              when :array: Array
              when :hash: Hash
              end
      check((value.nil? or value.is_a?(klass)), "Expected a #{type} for #{name}, got #{value.inspect}")
    end

    def check_numeric *values
      values.each do |v|
        check(v.is_a?(Numeric), "Expected a numeric value, got #{v.inspect}")
      end
    end

    def check_array *values
      values.each do |v|
        check(v.is_a?(Array), "Expected an array, got #{v.inspect}")
      end
    end

    def check_hash *values
      values.each do |v|
        check(v.is_a?(Hash), "Expected a hash, got #{v.inspect}")
      end
    end

    def check cond, message
      raise Error.new(message) unless cond
    end
  end

  class Error < RuntimeError
    attr_accessor :stack, :opcode, :pc, :locals

    def to_s
      a = [super]
      a << "stack: #{stack.inspect}" if stack
      a << "opcode: #{opcode.inspect}" if opcode
      a << "pc: #{pc.inspect}" if pc
      a << "locals: #{locals.inspect}" if locals
      a.join " "
    end
  end

  class Builder
    attr_accessor :name, :return_type
    attr_reader :vars, :params, :labels

    def initialize name
      @params = {}
      @vars = {}
      @return_type = nil
      @name = name
      @code = []

      @labels = {}
      @forward_references = {}
    end

    def param name, type
      check_type type
      @params[name.to_sym]=type
    end

    def remove_param name
      @params.delete name
    end

    def var name, type
      check_type type
      @vars[name.to_sym]=type
    end

    def remove_var name
      @vars.delete name
    end

    def return_type= type
      check_type type
      @return_type = type
    end

    def [] name
      @labels[name] = @code.size

      if @forward_references.has_key? name
        @forward_references[name].each do |idx|
          jmp = @code[idx]
          @code[idx] = [jmp, @labels[name]]
        end
        @forward_references.delete name
      end

      self
    end

    def code
      raise Error.new("Undefined forward references: #{@forward_references.keys.inspect}") unless
        @forward_references.empty?
      @code
    end

    def function
      Function.new name, :return=>return_type, :params=>params, :vars=>vars, :code=>code
    end

    ##################################################

    # No-argument opcodes
    %w{add sub mul div mod
       new_array new_hash
       dup return
       inc dec
       size lookup array_set array_append
       hash_set get}.each do |opcode|
      send :define_method, opcode.to_sym do
        @code << opcode.to_sym
      end
    end

    def push value
      check_value_type value
      @code << [:push, value]
    end

    # Things that take valid names
    %w{load store}.each do |opcode|
      send :define_method, opcode.to_sym do |name|
        check_name name
        @code << [opcode.to_sym, name.to_sym]
      end
    end

    # Kinds of jump
    %w{jmp jmpz jmplt jmple jmpgt jmpge}.each do |opcode|
      send :define_method, opcode.to_sym do |address|
        @code << if address.is_a? Numeric # Normal constant jump
                   [opcode.to_sym, address]
                 elsif @labels.has_key? address # Nackward reference
                   [opcode.to_sym, @labels[address]]
                 else # Forward reference
                   @forward_references[address] ||= []
                   @forward_references[address] << @code.size
                   opcode.to_sym
                 end
      end
    end

    private

    def check_type type
      raise Error.new("Invalid type #{type}") unless
        [:number, :string, :boolean, :array, :hash].index(type)
    end

    def check_value_type value
      raise Error.new("Expected scalar type, got #{value.inspect}") unless
        value.is_a?(Numeric) or value.is_a?(String) or value.is_a?(Boolean)
    end

    def check_name name
      raise Error.new("Unknown variable or parameter #{name}") unless
        @vars.has_key?(name) or @params.has_key?(name)
    end
  end
end
