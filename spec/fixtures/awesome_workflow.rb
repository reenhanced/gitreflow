class AwesomeWorkflow < GitReflow::Workflows::Core
  def start
    GitReflow.shell.say "Awesome."
  end
end

AwesomeWorkflow
