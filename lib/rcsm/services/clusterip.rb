##
# The Clusterip service is for managing iptables-based load sharing across
# multiple machines via a shared ip address.
# 
# *** The iptables/netfilter CLUSTERIP module
# All machines receive all requests,
# and each machine performs an algorithm on the source IP that turns it into a
# number between 1 and the number of nodes in the cluster. Each machine has a
# number that it is responsible for, and if its number matches the result of
# the hashing then it takes the request. Additionally, each machine can have more
# than one number or no number at all, which allows you to give the
# responsibility of one node to another in the case of maintenance or failure.
# 
# See the iptabels man page or http://www.linux-ha.org/ClusterIP for more info.
# 
# *** The Clusterip Service
# Right now, the Clusterip service reports the status of currently running
# ip addresses, and will start new addresses, stop currently assigned addresses
# (i.e. remove the address from a node), and shift request handling responsibility
# between nodes.
# 
# It might be helpful to note that under the hood, this consists of managing 3
# things: the shared ip (by default on eth0), the iptables entry,
# and the definition of responsibility (in /proc/net/ipt_CLUSTERIP/[ip address]).
# 
# Examples:
# 
# Start a new ip address on a node:
# 
# <code><pre>
# cip = node[:clusterip].instance(:ip => "10.0.0.100")
# cip.status # => "not running"
# cip.status(:v) # => not running: iptables, interface eth0:0
# cip.start
# cip.status # => "running"
# </pre></code>
class Rcsm::Service::Clusterip < Rcsm::Service
  DEFAULTS = {
    :interface => "eth0",
    :clustermac => "01:02:03:04:05:06",
    :hashmode => "sourceip"
  }
  
  # Returns an array of the CLUSTERIP addresses currently defined on a node
  # === Parameters
  # [+options+] - currently unused
  def instances(*options)
    options = options.to_options_hash
    
    ls = @node.exec("ls /proc/net/ipt_CLUSTERIP/")
    return [] if !ls || ls =~ /No such file or directory/
    
    ips = ls.split
    clusterips = []
    ips.each do |ip|
      clusterip = self.instance(:ip => ip)
      clusterips << clusterip
    end
    
    return clusterips
  end
  
end

class Rcsm::Service::ClusteripInstance < Rcsm::ServiceInstance
  ##
  # Returns the clusterip hash values this node is responsible for as integers
  # in an array.
  def responsibility
    res = @node.exec("sudo cat /proc/net/ipt_CLUSTERIP/#{ip}")
    return res ? res.split(",").collect {|i| i.to_i} : []
  end
  
  ##
  # Sets which requests this node will respond to.
  # === Behaviors
  # This method mimics what you would have to do by hand to shift responsibility
  # between nodes. You would do it by hand like:
  #
  # echo "[responsibility integer]" > /proc/net/ipt_CLUSTERIP/10.0.0.100
  # === Parameters
  # [+*args+] - a list or array of integers. Use a positive number to add
  #             responsibility to a node, and a negative number to take
  #             responsibility away from a node.
  #             
  #             *Examlpes:*
  #             
  #             give a node the responsibility to handle the requests of nodes
  #             1 and 2:
  #
  #             cip.responsibility = 1, 2
  #             (or cip.responsibility = [1, 2])
  #
  #             remove responsibility for handling node 2's requests:
  #             
  #             cip.responsibility = -2
  def responsibility=(*args)
    # the only problem with *args is that if someone puts in an array, we get
    # a two dimensional array. Let's fix this.
    args = args[0] if args[0].kind_of? Array
    
    commands = []
    args.each do |res_for|
      commands << "echo '#{"+" if res_for > 0}#{res_for}' | sudo tee /proc/net/ipt_CLUSTERIP/#{ip} > /dev/null"
    end
    @node.exec(commands.join("; "))
  end
  
  ##
  # Starts a Clusterip service by initializing the shared ip on the interface 
  # (default eth0) and defining the iptables rule. Note that the latter also
  # gives itself responsibility for itself (as defined by +local_node+ in the
  # configuration)
  def start
    if status != "running"
      commands = []
      commands << "sudo iptables -I INPUT -d #{ip} -i #{interface} -j CLUSTERIP --new --clustermac #{clustermac} --hashmode #{hashmode} --total-nodes #{total_nodes} --local-node #{@node.local_node}"
      commands << "sudo ip address add #{ip} dev eth0"
      @node.exec(commands.join("; "))
    end
  end
  
  ##
  # Removes the entry in iptables (which also deletes the responsibility file in
  # /proc/net/ipt_CLUSTERIP/[ip address]) and takes down the shared ip.
  # 
  # To simply remove request handling responsibility, you could do:
  # 
  # cip.responsibility = cip.responsibility.collect {|i| -i}
  # 
  # although you'll probably just want to use +migrate+
  def stop
    commands = []
    commands << "sudo iptables -D INPUT -d #{ip} -i #{interface} -j CLUSTERIP --new --clustermac #{clustermac} --hashmode #{hashmode} --total-nodes #{total_nodes} --local-node #{@node.local_node}"
    commands << "sudo ip address del #{ip} dev #{interface}"
    @node.exec(commands.join("; "))
  end
  
  ##
  # Moves the responsibility of a node from one node to another.
  # === Parameters
  # [+dst+] A Rcsm::Node instance to move the responsibility to
  def migrate(dst, *args)
    src_clusterip = self
    dst_clusterip = dst[:clusterip].instance(:ip => ip)

    if args.empty? # migrate everything
      src_responsibility = src_clusterip.responsibility
    else # migrate just the responsibility specified
      src_responsibility = args
    end
    
    dst_clusterip.responsibility = src_responsibility
    src_clusterip.responsibility = src_responsibility.collect {|i| -i}
  end
  
  ##
  # Returns the status of the clusterip service.
  # === Parameters
  # [+options+] +:v+, +:verbose+ - give the status of individual components
  #             of the CLUSTERIP implementation, i.e. the interface
  #             (usually eth0), the iptables entry, and the defined
  #             responsibility
  # === Returns
  # "running" if all three things are up (it has to be responsible for
  # at least 1 node for responsibilty to be considered 'up'), "not running"
  # otherwise.
  def status(*options)
    options = options.to_options_hash
    
    commands = []
    status = ""
    running = true
    iptables_status = @node.exec("sudo iptables -L INPUT -n | grep CLUSTERIP")
    if !(iptables_status =~ /^CLUSTERIP.*?#{ip}.*?total_nodes=#{total_nodes}.*?local_node=#{@node.local_node}/)
      running = false
      if options[:v] || options[:verbose]
        status += "not running: iptables\n"
      else
        return "not running"
      end
    end
    
    ip_addy_status = @node.exec("ip address show #{interface} | grep #{ip}")
    if !(ip_addy_status =~ /inet #{ip}/)
      running = false
      if options[:v] || options[:verbose]
        status += "not running: #{ip} on #{interface}\n"
      else
        return "not running"
      end
    end
    
    if self.responsibility.size == 0
      running = false
      if options[:v] || options[:verbose]
        status += "not responsible for any nodes\n"
      else
        return "not running"
      end
    end
    
    if running
      if options[:v] || options[:verbose]
        status = "running, #{interface}, #{responsibility}"
      else
        status = "running"
      end
    end
    return status
  end
  
  def to_s(*status_options)
    "#{ip}: #{status(*status_options)}"
  end
  
end
