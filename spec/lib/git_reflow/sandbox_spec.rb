require 'spec_helper'

RSpec.describe GitReflow::Sandbox do
  describe ".run" do
    it "is blocking by default when the command exits with a failure" do
      allow(GitReflow::Sandbox).to receive(:run).and_call_original
      expect { GitReflow::Sandbox.run("ls wtf") }.to raise_error SystemExit, "\`ls wtf\` failed to run."
    end

    it "when blocking is flagged off, the command exits silently" do
      allow(GitReflow::Sandbox).to receive(:run).and_call_original
      expect { GitReflow::Sandbox.run("ls wtf", blocking: false) }.to_not raise_error SystemExit
    end
  end
end
