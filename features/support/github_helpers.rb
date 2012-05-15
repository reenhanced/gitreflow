require File.expand_path('../../../spec/support/github_helpers', __FILE__)

World(GithubHelpers)

# the github_api gem does some overrides to Hash so we have to make sure
# this still works here...
class Hash
  def except(*keys)
    cpy = self.dup
    keys.each { |key| cpy.delete(key) }
    cpy
  end
end
