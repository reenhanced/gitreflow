require 'spec_helper'

describe GitReflow::Config do
  describe ".get(key)" do
    subject { GitReflow::Config.get('chucknorris.roundhouse') }
    it      { expect{ subject }.to have_run_command_silently 'git config --get chucknorris.roundhouse', blocking: false }

    context "and getting all values" do
      subject { GitReflow::Config.get('chucknorris.roundhouse-kick', all: true) }
      it      { expect{ subject }.to have_run_command_silently 'git config --get-all chucknorris.roundhouse-kick', blocking: false }

      context "and checking locally only" do
        subject { GitReflow::Config.get('chucknorris.jump', local: true) }
        it      { expect{ subject }.to have_run_command_silently 'git config --local --get chucknorris.jump', blocking: false }
      end
    end

    context "and checking for updates" do
      before  { GitReflow::Config.get('chucknorris.roundhouse') }
      subject { GitReflow::Config.get('chucknorris.roundhouse') }
      it      { expect{ subject }.to_not have_run_command_silently 'git config --get chucknorris.roundhouse-kick', blocking: false }
    end

    context "and checking locally only" do
      subject { GitReflow::Config.get('chucknorris.smash', local: true) }
      it      { expect{ subject }.to have_run_command_silently 'git config --local --get chucknorris.smash', blocking: false }
    end
  end

  describe ".set(key)" do
    subject { GitReflow::Config.set('chucknorris.roundhouse', 'to the face') }
    it      { expect{ subject }.to have_run_command_silently "git config -f #{ENV['HOME']}/.gitconfig.reflow --replace-all chucknorris.roundhouse \"to the face\"", blocking: false }

    context "for current project only" do
      subject { GitReflow::Config.set('chucknorris.roundhouse', 'to the face', local: true) }
      it      { expect{ subject }.to have_run_command_silently 'git config --replace-all chucknorris.roundhouse "to the face"', blocking: false }
    end
  end

  describe ".unset(key)" do
    subject { GitReflow::Config.unset('chucknorris.roundhouse') }
    it      { expect{ subject }.to have_run_command_silently "git config -f #{ENV['HOME']}/.gitconfig.reflow --unset-all chucknorris.roundhouse ", blocking: false }

    context "for multi-value keys" do
      subject { GitReflow::Config.unset('chucknorris.roundhouse', value: 'to the face') }
      it      { expect{ subject }.to have_run_command_silently "git config -f #{ENV['HOME']}/.gitconfig.reflow --unset-all chucknorris.roundhouse \"to the face\"", blocking: false }
    end

    context "for current project only" do
      subject { GitReflow::Config.unset('chucknorris.roundhouse', local: true) }
      it      { expect{ subject }.to have_run_command_silently 'git config --unset-all chucknorris.roundhouse ', blocking: false }

      context "for multi-value keys" do
        subject { GitReflow::Config.unset('chucknorris.roundhouse', value: 'to the face', local: true) }
        it      { expect{ subject }.to have_run_command_silently 'git config --unset-all chucknorris.roundhouse "to the face"', blocking: false }
      end
    end
  end

  describe ".add(key)" do
    subject { GitReflow::Config.add('chucknorris.roundhouse', 'to the face') }
    it      { expect{ subject }.to have_run_command_silently "git config -f #{GitReflow::Config::CONFIG_FILE_PATH} --add chucknorris.roundhouse \"to the face\"", blocking: false }

    context "for current project only" do
      subject { GitReflow::Config.add('chucknorris.roundhouse', 'to the face', local: true) }
      it      { expect{ subject }.to have_run_command_silently 'git config --add chucknorris.roundhouse "to the face"', blocking: false }
    end

    context "globally" do
      subject { GitReflow::Config.add('chucknorris.roundhouse', 'to the face', global: true) }
      it      { expect{ subject }.to have_run_command_silently 'git config --global --add chucknorris.roundhouse "to the face"', blocking: false }
    end
  end
end
