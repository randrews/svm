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

  def function name
    SVM::Function.new name, @fn[name]
  end
end
