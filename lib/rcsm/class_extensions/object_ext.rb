class Object
  # Stores options hash in an instance variable on the object and initializes
  # instance variables based on that hash, including attr_readers.
  # 
  # === Parameters
  # [+*options+] An array that will be turned into a hash of key-value pairs
  #              to be initialized.
  #              
  #              Can take flags that will automatically be set to true.
  #              For example, Object.initialize_options(:debug_mode, :port => 3000)
  #              would create 
  #              {:debug_mode => true, :port => 3000}. Caveat: flags MUST come
  #              before key-value options. See +to_options_hash+ for more info.
  # === Returns
  # Nothing in particular (values are set on the object, so no need for a
  # return value)
  # === Raises
  # nothing
  def initialize_options(*options)
    # if +options+ was passed in as the array resulting from argument
    # explosion rather than the argument itself (i.e. options instead of
    # *options) then we will receive something like [:flag, {:key => "value"}],
    # rather than :flag, {:key => "value"}. Then, the *options here
    # will make it [[:flag, {:key => "value"}]], which will be turned into
    # {[:flag, {:key => "value"}] => true}. Let's just account for both to
    # avoid that:
    if options.size == 1 && options[0].kind_of?(Array)
      options = options[0]
    end
    
    options = options.to_options_hash
    
    # set an instance variable / attr_reader for the options hash
    self.instance_variable_set("@options", options)
    self.class.send(:attr_reader, :options)
    
    # initialize option instance variables and attr_readers
    options.each do |key, value| 
      self.instance_variable_set("@#{key}", value)
      self.class.send(:attr_reader, key.to_sym)
    end
  end
end
