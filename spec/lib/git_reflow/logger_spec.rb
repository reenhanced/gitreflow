require 'spec_helper'

describe GitReflow::Logger do
  context "defaults" do
    it "logs to '/tmp/git-reflow.log' by default" do
      logger = described_class.new
      expect(logger.instance_variable_get("@logdev").dev.path).to eq GitReflow::Logger::DEFAULT_LOG_FILE
    end
  end
end
