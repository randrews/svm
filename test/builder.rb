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
end
