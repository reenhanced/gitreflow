class WorkflowWithSuper < GitReflow::Workflows::Core
  def start
    GitReflow.shell.say "Super."
    super(nil)
  end
end

WorkflowWithSuper
