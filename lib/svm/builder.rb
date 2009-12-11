class SVM::Builder
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
    raise SVM::Error.new("Undefined forward references: #{@forward_references.keys.inspect}") unless
      @forward_references.empty?
    @code
  end

  def function
    SVM::Function.new name, :return=>return_type, :params=>params, :vars=>vars, :code=>code
  end

  ##################################################

  # No-argument opcodes
  %w{add sub mul div mod inc dec
       dup return
       anew size aget aset apush
       hnew hset hget}.each do |opcode|
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
  %w{jmp jmpz jmpnz jmplt jmple jmpgt jmpge jmpeq jmpne}.each do |opcode|
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
    raise SVM::Error.new("Invalid type #{type}") unless
      [:number, :string, :boolean, :array, :hash].index(type)
  end

  def check_value_type value
    raise SVM::Error.new("Expected scalar type, got #{value.inspect}") unless
      value.is_a?(Numeric) or value.is_a?(String) or value.is_a?(Boolean)
  end

  def check_name name
    raise SVM::Error.new("Unknown variable or parameter #{name}") unless
      @vars.has_key?(name) or @params.has_key?(name)
  end
end
