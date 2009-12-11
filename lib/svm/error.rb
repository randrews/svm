class SVM::Error < RuntimeError
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
