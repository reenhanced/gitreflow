class WorkflowWithSuper < GitReflow::Workflows::Core
  def self.start(**args)
    GitReflow.say "Super."
    super(feature_branch: args[:feature_branch], base: args[:base])
  end
end

WorkflowWithSuper
