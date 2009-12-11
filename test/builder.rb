require "rubygems"
require "spec"
require "svm.rb"

describe "SVM::Builder" do
  it "should let me build a function with the builder" do
    b = SVM::Builder.new("foo")
    b.add
    b.add
    b.return

    b.code.should==[:add, :add, :return]
    b.name.should=="foo"
  end

  it "should let me build a function with parameter opcodes" do
    b = SVM::Builder.new("foo")
    b.param :x, :number
    b.var :y, :number

    b.load :x
    b.inc
    b.store :y

    b.code.should==[ [:load, :x], :inc, [:store, :y] ]
    b.vars.should=={:y=>:number}
    b.params.should=={:x=>:number}
  end

  it "should accept labels" do
    b = SVM::Builder.new("foo")
    b[:start].push 0

    b.labels.should=={:start=>0}
  end

  it "should accept constant jumps" do
    b = SVM::Builder.new("foo")
    b.push 0
    b.jmp 0

    b.code.should==[[:push, 0], [:jmp, 0]]
  end

  it "should accept jumps to backward references" do
    b = SVM::Builder.new("foo")
    b.push 0
    b[:start].inc
    b.jmp :start

    b.code.should==[[:push, 0], :inc, [:jmp, 1]]
  end

  it "should accept jumps to forward references" do
    b = SVM::Builder.new("foo")
    b.jmp :end
    b.inc
    b[:end].return

    b.code.should==[[:jmp, 2], :inc, :return]
  end

  it "should raise an error with an undefined forward reference" do
    b = SVM::Builder.new("foo")
    b.jmp :nowhere
    b.return

    lambda { b.code }.should raise_error SVM::Error
  end

  it "should let me create a function" do
    b = SVM::Builder.new("square")
    b.param :x, :number
    b.return_type = :number

    b.load :x
    b.dup
    b.mul
    b.return

    b.function.class.should==SVM::Function
  end

  it "should let me create a function that runs" do
    b = SVM::Builder.new("square")
    b.param :x, :number
    b.return_type = :number

    b.load :x
    b.dup
    b.mul
    b.return

    b.function.apply(:x=>5).should==25
  end

  it "should fail to create incomplete functions" do
    b = SVM::Builder.new("square")

    # Error because of no return type
    lambda{ b.function }.should raise_error SVM::Error
  end

  it "should let me build a simple example function" do
    b = SVM::Builder.new "square"
    b.return_type = :number
    b.param :n, :number
    b.load :n
    b.dup
    b.mul
    b.return

    func = b.function
    func.apply({:n => 9}).should === 81
  end

  it "should let me build a complex example function" do
    # Example from the readme, because it would be embarrassing if this didn't work

    b = SVM::Builder.new "total"
    b.return_type = :number
    b.param :a, :array
    b.var :index, :number
    b.var :total, :number
    b.push 0
    b.store :index
    b.push 0
    b.store :total
    b[:header].load :a
    b.size
    b.load :index
    b.jmplt :body
    b.load :total
    b.return
    b[:body].load :a
    b.load :index
    b.aget # Now the stack contains a[index]
    b.load :total
    b.add # Now the stack has total, with the next value added in
    b.store :total # . . . Which we store back in total
    b.load :index
    b.inc
    b.store :index
    b.jmp :header

    func = b.function
    func.apply(:a=>[1, 3, 5, 7, 9]).should == 25
  end
end
