require "rubygems"
require "activesupport" # For the base extensions, we'll drop this later

module SVM
  class Function
    attr_reader :code, :return_type, :params, :name

    def initialize name, opts
      opts = opts.symbolize_keys
      @code = opts[:code].map{|op| (op.is_a?(Array) ? (op[0] = op.first.to_sym) : (op = op.to_sym)) ; op } 
      @return_type = opts[:return].to_sym
      @params = {} ; opts[:params].each{|k,v| @params[k.to_sym] = v.to_sym}
      @name = name
    end

    def apply args
      check_params args

      stack = []
      ret = nil
      pc = 0

      loop do
        check(pc >= 0 && pc < code.size, "Program counter out of bounds: #{pc}")

        op = code[pc]

        case (op.is_a?(Array) ? op.first : op)
          when :return
          ret = stack.pop
          break

          when :push
          stack.push op[1]

          when :var
          stack.push args[op[1].to_sym]

          when :add
          a = stack.pop
          b = stack.pop
          check(a.is_a?(Numeric), "Expected a numeric value, got #{a.inspect}")
          check(b.is_a?(Numeric), "Expected a numeric value, got #{b.inspect}")
          stack.push a+b

          when :mul
          a = stack.pop
          b = stack.pop
          check(a.is_a?(Numeric), "Expected a numeric value, got #{a.inspect}")
          check(b.is_a?(Numeric), "Expected a numeric value, got #{b.inspect}")
          stack.push a*b

          else
          check false, "Invalid opcode: #{op.inspect}"
        end

        pc += 1
      end

      ret
    end

    def check_params args
      params.each do |name, type|
        klass = case type
                when :number: Numeric
                when :string: String
                end
        check args[name].is_a?(klass), "Expected #{name} to be #{type}, not #{args[name].inspect}"
      end
    end

    def check cond, message
      raise Error.new(message) unless cond
    end
  end

  class Error < RuntimeError
  end
end
