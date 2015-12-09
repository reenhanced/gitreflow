require 'spec_helper'

describe GitReflow::TrelloWorkflow do

  describe "#setup" do
    let(:trello_key)   { 'abc123' }
    let(:member_token) { '12345' }
    let(:member_id)    { 1 }
    let(:board_name)   { 'GitReflow' }

    before do
      stub_input_with({
        "Enter your Developer API Key found on the URL above: "   => trello_key,
        "Enter your Member Token generated from the URL above: " => member_token,
        "Enter the name of the Trello board for this project: " => board_name
      })
    end

    it "stores the trello api-key and member-token in the git config" do
      allow(GitReflow::Config).to receive(:set).with('trello.api-key', trello_key)
      allow(GitReflow::Config).to receive(:set).with('trello.member-token', member_token)
      allow(Trello).to receive(:configure).and_return(member_token)
      allow(Trello::Token).to receive(:find).with(member_token).and_return(double(:response, member_id: member_id))
      allow(GitReflow::Config).to receive(:set).with('trello.member-id', member_id, local: true)
      allow(GitReflow::Config).to receive(:set).with('trello.next-list-id', 'Next', local: true)
      allow(GitReflow::Config).to receive(:set).with('trello.current-list-id', 'In Progress', local: true)
      allow(GitReflow::Config).to receive(:set).with('trello.staged-list-id', 'Staged', local: true)
      allow(GitReflow::Config).to receive(:set).with('trello.approved-list-id', 'Approved', local: true)
      allow(GitReflow::Config).to receive(:set).with('trello.completed-list-id', 'Live', local: true)
      allow(GitReflow::Config).to receive(:set).with('trello.board-id', board_name, local: true)
      subject.setup
    end
  end

  describe "#current_trello_member" do
    let(:member_id) { "ricky-bobby" }
    subject         { GitReflow::TrelloWorkflow.current_trello_member }
    before do
      allow(GitReflow::Config).to receive(:get).with('trello.member-id').and_return(member_id)
    end
    context "a Trello member exists for the given id" do
      let(:trello_member) { double(:trello_member) }
      before { allow(Trello::Member).to receive(:find).with(member_id).and_return(trello_member) }
      it { should eql(trello_member) }
    end
    context "no Trello member exists for the given id" do
      before { allow(Trello::Member).to receive(:find).and_raise(Trello::Error) }
      it { should eql(nil) }
    end
  end
end
