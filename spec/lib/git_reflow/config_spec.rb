require 'spec_helper'

describe GitReflow::Config do
  context "class methods" do
    describe ".get(key)" do
      subject { GitReflow::Config.get() }
    end
  end
end
