class FlatMerge < GitReflow::Workflows::Core
  def self.deliver(**params)
    base_branch     = params[:base] || 'master'
    params[:squash] = false

    super(**params)
  end
end

FlatMerge
