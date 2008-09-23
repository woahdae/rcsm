module Enumerable
  # this turns an options array like [:flag1, :flag2, :option => "value"]
  # to {:flag1 => true, :flag2 => true, :option => "value"}. Note that flags
  # MUST come before options (although there can be multiple of both).
  # 
  # This lets you define methods like:
  # 
  # def my_method(arg1, arg2, *options); stuff...; end
  # 
  # call it like:
  # 
  # my_method("arg1", "arg2", :flag, :option => "value")
  # 
  # and use it like:
  # 
  # options = options.to_option_hash
  # if options[:flag]
  # ...
  # end
  # 
  # Two things to note when using this as described:
  # * again, you MUST specify flags before options, ex.
  #   my_method("arg1", "arg2", :option => "value", :flag)
  #   will NOT work!
  # * this is backwards compatible with the usual 
  #  {:flag => true, :option => "value"}, i.e. you can
  #   pass that in as *options and it'll work just fine.
  # 
  # Credit: James Coglan, http://www.ruby-forum.com/topic/165080#724668
  def to_options_hash(value = true)
    ary = entries
    options = (Hash === ary.last) ? ary.pop : {}
    ary.each { |key| options[key] = value }
    options
  end
end
