require File.dirname(__FILE__) + '/spec_helper.rb'

describe "exec" do
  before(:each) do
    @node = Rcsm::Node.new('127.0.0.1', :password => "izzoaoeu", :user => 'woody')
  end
  
  it "should execute a remote command and return the results" do
    @node.exec("echo 'hello'").should == 'hello'
  end
  
  # # commented because it will complain that you haven't set a sudo password.
  # # you could set password => 'pass' above and uncomment to check that it works,
  # # but I don't want to require that users put their password somewhere just for
  # # testing.
  # it "should execute a remote command with sudo and return the results" do
  #   @node.exec("sudo echo 'hello'").should == 'hello'
  # end
  
  it "should raise a RuntimeError when sudo asks for a password, but the connection doesn't have one set" do
    password = @node.instance_variable_get(:@password)
    @node.instance_variable_set(:@password, nil)
    lambda { @node.exec("sudo echo 'hello'") }.should raise_error(RuntimeError)
    @node.instance_variable_set(:@password, password)
  end
  
  describe "get_host_and_user" do
    before(:each) do
      Rcsm::Node.send(:public, :get_host_and_user)
      @node = Rcsm::Node.new("localhost")
    end
    
    it "should parse 'login@somehost' to {:hostname=>'somehost', :user=>'login'}" do
      @node.get_host_and_user("login@somehost").should == {:hostname=>"somehost", :user=>"login"}
    end

    it "should parse 'user@somehost', :user => 'someone_else' to {:hostname=>'somehost', :user=>'someone_else'}" do
      @node.get_host_and_user("login@somehost", :user => "someone_else").should == {:hostname=>"somehost", :user=>"someone_else"}
    end
    
    it "should parse 'somehost' to {:hostname=>'somehost', :user=>'logged_in_user'}" do
      Etc.should_receive(:getlogin).and_return("logged_in_user")
      @node.get_host_and_user("somehost").should == {:hostname=>"somehost", :user=>"logged_in_user"}
    end
  end
  
  describe "local?" do
    it "should return true when hostname == 'localhost'" do
      node = Rcsm::Node.new("localhost")
      node.should be_local
    end

    it "should return true when hostname is the same as the real hostname" do
      node = Rcsm::Node.new("some_hostname")
      Socket.stub!(:gethostname).and_return("some_hostname")
      node.should be_local
    end
    
    it "should return false if hostname isn't localhost or the real hostname" do
      node = Rcsm::Node.new("a_hostname_that_is_not_this_computer")
      node.should_not be_local
    end
  end
  
end