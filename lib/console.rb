class << self
  $nodes.each do |node|
    define_method node.hostname do
      return node
    end
  end
end
