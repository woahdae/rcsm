require File.dirname(__FILE__) + '/../spec_helper'

describe Enumerable do
  describe "to_options_hash" do
    it "should turn an array into a hash of options with lone keys given values of true" do
      arr = [:this, :that, {:woo => "hoo"}]
      hash = arr.to_options_hash
      hash.should == {:this => true, :that => true, :woo => "hoo"}
    end
  end
end
