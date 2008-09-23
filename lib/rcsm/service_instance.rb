
##
# === Creating New Services
# See Rcsm::Service documentation
class Rcsm::ServiceInstance 
  attr_accessor :service_name, :node, :options
  
  ##
  # For creating new Rcsm::ServiceInstance *subclass* instances.
  # 
  # You can call new on a subclass to create Service instances
  # (e.g. Rcsm::Service::MongrelInstance.new(node)), or use
  # Rcsm::ServiceInstance.factory. One is almost always cleaner than the other.
  # === Behaviors
  # * Stores all +*option+ values in their own instance variable
  # * stores the node, service_name, and options in instance variables
  # === Parameters
  # [+node+]      A Rcsm::Node subclass instance, ex. Rcsm::RemoteNode
  # [+*options+] Options needed to initialize the particular ServiceInstance.
  #              Ex, a mongrel service instance would need to know what port
  #              to run on (among other things), while an ip address would
  #              need to know what its ip address is. These will be
  #              stored as a hash in the @options instance variable for later
  #              reference in methods such as start, stop, status, etc.
  # 
  #              It is interesting to note that +*options+ can take unix-like
  #              flags that will automatically be set to true in the options hash.
  #              For example, ServiceInstance.new(node, :debug_mode, :port => 3000)
  #              would produce an options hash of 
  #              {:debug_mode => true, :port => 3000}. Caveat: flags MUST come
  #              before key-value options. See +to_options_hash+ for more info.
  # === Returns
  # Nothing in particular
  # === Raises
  # * RuntimeError if new is called from Rcsm::ServiceInstance
  def initialize(node, *options)
    if self.class == Rcsm::ServiceInstance
      raise "Cannot call new from Rcsm::ServiceInstance - use factory instead"
    end
    
    @node = node
    @service_name = self.class.service_name
    
    service_class = Kernel.qualified_const_get("Rcsm::Service::#{@service_name}")
    initialize_options(service_class.final_options(*options))
  end
  
  ##
  # Convenience method that creates a new Rcsm::ServiceInstance subclass
  # instance based on the +service_name+ parameter, aka
  # "Rcsm::Service::[ServiceName]Instance"
  # 
  # Ex. Rcsm::ServiceInstance.factory(:mongrel, node, :port => 3000) would
  # call Rcsm::Service::MongrelInstance.new(node, :port => 3000)
  # 
  # Note: although .new and .factory do the same thing, one is almost always
  # cleaner than the other in a given context.
  # === Parameters
  # [+service_name+] A service name, ex. +Mongrel+. Note that it is not case
  #                  or Symbol-sensitive, so :mongrel would work also
  # [+node+]          A Rcsm::Node subclass instance, ex. Rcsm::RemoteNode
  # [+*options+]     Options to be passed to [ServiceName]Instance.new
  # === Returns
  # Newly instantiated Rcsm::Service::[ServiceName]Instance object
  # === Raises
  # nothing
  def self.factory(service_name, node, *options)
    klass = "Rcsm::Service::#{service_name.to_s.camelize}Instance"
    Kernel.qualified_const_get(klass).new(node, *options)
  end
  
  ##
  # Migrates the instance from its current node to another
  # === Behaviors
  # * Stops the instance on the current node and starts a new instance on the
  #   destination node using the same options.
  # === Parameters
  # [+dst+] Rcsm::Node subclass instance
  # === Returns
  # The newly started instance
  # === Raises
  # nothing
  def migrate(dst)
    self.stop
    new_instance = self.class.new(@node, @options)
    new_instance.start
    return new_instance
  end

  def start(*options); end
  
  def stop(*options); end
  
  def restart(*options); end
  
  def status(*options); end
  
  ##### Misc #####
  
  def to_sym # :nodoc:
    self.service_name.underscore.to_sym
  end
  
  def self.service_name
    self.to_s =~ /(\w*?)Instance$/
    return $1
  end
  
end