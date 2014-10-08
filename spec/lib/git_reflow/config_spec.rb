require 'spec_helper'

describe GitReflow::Config do
  describe ".get(key)" do
    subject { GitReflow::Config.get('chucknorris.roundhouse') }
    it      { expect{ subject }.to have_run_command_silently 'git config --get chucknorris.roundhouse' }
  end

  describe ".set(key)" do
    subject { GitReflow::Config.set('chucknorris.roundhouse', 'to the face') }
    it      { expect{ subject }.to have_run_command_silently 'git config --global --replace-all chucknorris.roundhouse "to the face"' }

    context "for current project only" do
      subject { GitReflow::Config.set('chucknorris.roundhouse', 'to the face', local: true) }
      it      { expect{ subject }.to have_run_command_silently 'git config --replace-all chucknorris.roundhouse "to the face"' }
    end
  end
end
