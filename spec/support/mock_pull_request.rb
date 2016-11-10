class MockPullRequest < GitReflow::GitServer::PullRequest
  DESCRIPTION         = "Bingo! Unity."
  HTML_URL            = "https://github.com/reenhanced/gitreflow/pulls/0"
  FEATURE_BRANCH_NAME = "feature_branch"
  BASE_BRANCH_NAME    = "base"
  NUMBER              = 0

  def initialize(attributes = Struct.new(:description, :html_url, :feature_branch_name, :base_branch_name, :number).new)
    self.description         = attributes.description || DESCRIPTION
    self.html_url            = attributes.html_url || HTML_URL
    self.feature_branch_name = attributes.feature_branch_name || FEATURE_BRANCH_NAME
    self.base_branch_name    = attributes.base_branch_name || BASE_BRANCH_NAME
    self.build               = Build.new
    self.number              = attributes.number || NUMBER
    self.source_object       = attributes
  end
end
