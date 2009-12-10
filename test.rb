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
    func.params.should=={"x"=>:number}
  end

  it "should evaluate a function" do
    func = function "test1"
    func.apply(:x=>5).should==13
  end

  it "should detect errors in params" do
    func = function "test1"
    lambda{ func.apply(:x=>"foo") }.should raise_error SVM::Error
  end

  def function name
    SVM::Function.new name, @fn[name]
  end
end
