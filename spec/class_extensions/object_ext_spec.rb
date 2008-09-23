require File.dirname(__FILE__) + '/../spec_helper'

describe Object do
  describe "initialize_options" do
    before(:each) do
      @object = Object.new
      @object.initialize_options(
        :flag,
        :ip => "123.456.78.90",
        :something => "else"
      )
    end
    
    it "should initialize instance variables for each option" do
      @object.instance_variable_defined?(:@ip).should be_true
      @object.instance_variable_defined?(:@flag).should be_true
      @object.instance_variable_defined?(:@something).should be_true
    end
    
    it "should create accessors for each option key and set the values correctly" do
      @object.ip.should == "123.456.78.90"
      @object.something.should == "else"
      @object.flag.should == true
    end
    
    it "should work when called by passing 'options' and not '*options'" do
      # this happens if you define a method like:
      # 
      # def do_stuff(*options)
      #   initialize_options(options)
      # end
      # 
      # notice passing options and not *options. This will pass in 
      # [:flag, {:key => "value"}], which if unnoticed would be turned into
      # {[:flag, {:key => "value"}] => true}
      @object = Object.new
      bad_options = [ :flag, {
        :ip => "123.456.78.90",
        :something => "else"
      }]
      @object.initialize_options(bad_options)
      @object.ip.should == "123.456.78.90"
      @object.something.should == "else"
      @object.flag.should == true
    end
  end
end