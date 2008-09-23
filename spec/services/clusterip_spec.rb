require File.dirname(__FILE__) + '/../spec_helper'

describe Rcsm::Service::Clusterip do
  describe "instances" do
    it "should return an array of ClusteripInstance objects" do
      @node = mock(Rcsm::Node)
      @node.stub!(:exec).with("ls /proc/net/ipt_CLUSTERIP/").and_return("123.456.78.90  123.456.78.91")
      @clusterip_service = Rcsm::Service::Clusterip.new(@node)
      
      # do some checks
      ips = @clusterip_service.instances
      ips.first.class.should == Rcsm::Service::ClusteripInstance
      ips.size.should == 2
    end
  end
end

describe Rcsm::Service::ClusteripInstance do
  before(:each) do
    @node = mock(Rcsm::Node, :local_node => 1)
    @cip_instance = Rcsm::Service::ClusteripInstance.new(@node, 
      :ip => "123.456.78.90",
      :total_nodes => 3
    )
  end

  describe "responsibility" do
    it "should return an array of stringified numbers representing which
        fraction of all total nodes this node is responsible for" do
      @node.should_receive(:exec).
        with('sudo cat /proc/net/ipt_CLUSTERIP/123.456.78.90').
        and_return("1,2")
      @cip_instance.responsibility.should == [1,2]
    end
  end
  
  describe "responsibility=" do
    it "should add the clusterip responsibility to the specified ip" do
      @node.should_receive(:exec).
        with("echo '+1' | sudo tee /proc/net/ipt_CLUSTERIP/123.456.78.90 > /dev/null; echo '-2' | sudo tee /proc/net/ipt_CLUSTERIP/123.456.78.90 > /dev/null")
      @cip_instance.responsibility = 1,-2
    end
    
    it "should work even when passed an array" do
      @node.should_receive(:exec).
        with("echo '+1' | sudo tee /proc/net/ipt_CLUSTERIP/123.456.78.90 > /dev/null; echo '-2' | sudo tee /proc/net/ipt_CLUSTERIP/123.456.78.90 > /dev/null")
      @cip_instance.responsibility = [1,-2]
    end
  end
  
  describe "start" do
    it "should start the clusterip service on the node" do
      @node.should_receive(:exec).with("sudo iptables -I INPUT -d 123.456.78.90 -i eth0 -j CLUSTERIP --new --clustermac 01:02:03:04:05:06 --hashmode sourceip --total-nodes 3 --local-node 1; sudo ifconfig eth0:0 123.456.78.90")
      @cip_instance.start
    end
  end
  
  describe "stop" do
    it "should stop the clusterip service on the node" do
      @node.should_receive(:exec).with("sudo iptables -D INPUT -d 123.456.78.90 -i eth0 -j CLUSTERIP --new --clustermac 01:02:03:04:05:06 --hashmode sourceip --total-nodes 3 --local-node 1; sudo ifconfig eth0:0 down")
      @cip_instance.stop
    end
  end
  
  describe "status" do
    before(:each) do
      @node.stub!(:exec).
        with("sudo iptables -L INPUT -n | grep CLUSTERIP").
        and_return("CLUSTERIP  0    --  0.0.0.0/0            123.456.78.90          CLUSTERIP hashmode=sourceip clustermac=01:02:03:04:05:06 total_nodes=3 local_node=1 hash_init=0")
      
      @node.stub!(:exec).
        with("sudo ifconfig | grep 123.456.78.90").
        and_return("inet addr:123.456.78.90  Bcast:10.255.255.255  Mask:255.0.0.0")
        
      @cip_instance.stub!(:responsibility).and_return([1])
    end
    it "should return 'running' when all things match up correctly" do
      @cip_instance.status.should == "running"
    end
    
    it "should return 'not running' when iptables is down" do
      @node.stub!(:exec).
        with("sudo iptables -L INPUT -n | grep CLUSTERIP").
        and_return(nil)
        
      @cip_instance.status.should == "not running"
    end

    it "should return 'not running' when interface is down" do
      @node.stub!(:exec).
        with("sudo ifconfig | grep 123.456.78.90").
        and_return(nil)
        
      @cip_instance.status.should == "not running"
    end
    
    it "should return 'not running' when not responsible for anything" do
      @cip_instance.stub!(:responsibility).and_return([])
      
      @cip_instance.status.should == "not running"
    end
    
    it "should return verbose output with the :v flag on failure" do
      @node.stub!(:exec).
        with("sudo iptables -L INPUT -n | grep CLUSTERIP").
        and_return(nil)
      
      @node.stub!(:exec).
        with("sudo ifconfig | grep 123.456.78.90").
        and_return(nil)
        
      @cip_instance.stub!(:responsibility).and_return([])
      
      @cip_instance.status(:v).should == "not running: iptables\nnot running: interface eth0:0\nnot responsible for any nodes\n"
    end
  end
  
  describe "migrate" do
    before(:each) do
      @dst_cip_instance = mock(Rcsm::Service::ClusteripInstance)
      @dst_cip_service = mock(Rcsm::Service::Clusterip, :instance => @dst_cip_instance)
      @dst = mock(Rcsm::Node, :[] => @dst_cip_service)
      @cip_instance.stub!(:responsibility).and_return([1,2])
    end
    
    it "should subtract src's node responsibility, and add it to dst's responsibility" do
      @cip_instance.should_receive(:responsibility=).with([-1,-2])
      @dst_cip_instance.should_receive(:responsibility=).with([1,2])
      @cip_instance.migrate(@dst)
    end
    
    it "should subtract specified responsibility from src node, and add it to dst_node" do
      @cip_instance.should_receive(:responsibility=).with([-1])
      @dst_cip_instance.should_receive(:responsibility=).with([1])
      @cip_instance.migrate(@dst, 1)
    end
  end
end






