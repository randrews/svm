require "rubygems"
require "spec"
require "svm.rb"

describe "SVM::Function" do
  before :all do
    @fn = YAML.load(File.open("test.yml"))
  end

  it "should create a function" do
    func = function "test1"
    func.name.should=="test1"
    func.return_type.should==:number
    func.params.should=={:x=>:number}
  end

  it "should evaluate a function" do
    func = function "test1"
    func.apply(:x=>5).should==13
  end

  it "should detect errors in params" do
    func = function "test1"
    lambda{ func.apply(:x=>"foo") }.should raise_error SVM::Error
  end

  it "should recognize missing parameters" do
    lambda{ function("loop1").apply() }.should raise_error SVM::Error
  end

  it "should recognize extra parameters" do
    lambda{ function("loop1").apply(:foo=>"bar") }.should raise_error SVM::Error
  end

  it "should eval the loop test" do
    function("loop1").apply(:times=>4).should==10
    function("loop1").apply(:times=>1).should==1
    function("loop1").apply(:times=>0).should==0
    function("loop1").apply(:times=>-1).should==0
  end

  it "should read a function that takes an array" do
    lambda{ function("average") }.should_not raise_error
  end

  it "should apply a function that takes an array" do
    function("average").apply(:values=>[25, 7, 8, 6, 4]).should==10
  end

  it "should apply a function that returns an array" do
    function("range").apply(:min=>0, :max=>5).should==[0,1,2,3,4]
  end

  it "should apply a function that uses hashes" do
    function("even_odd").apply(:values=>[1,2,3,4,5]).should=={"even"=>[2, 4], "odd"=>[1, 3, 5]}
    function("even_odd").apply(:values=>[2,2,2,3,5]).should=={"even"=>[2, 2, 2], "odd"=>[3, 5]}
  end

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

  def function name
    SVM::Function.new name, @fn[name]
  end
end
