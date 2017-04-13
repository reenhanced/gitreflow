require 'spec_helper'

describe GitReflow::Logger do
  context "defaults" do
    it "logs to '/tmp/git-reflow.log' by default" do
      logger = described_class.new
      expect(logger.instance_variable_get("@logdev").dev.path).to eq GitReflow::Logger::DEFAULT_LOG_FILE
    end

    context "when a log path is configured " do
      it "initializes a new logger with the given path" do
        allow(GitReflow::Config).to receive(:get).with("reflow.log_file_path").and_return("kenny-loggins.log")
        logger = described_class.new
        expect(logger.instance_variable_get("@logdev").dev.path).to eq "kenny-loggins.log"
      end
    end
  end
end
