class AwesomeWorkflow < GitReflow::Workflows::Core
  def self.start(**args)
    GitReflow.say "Awesome."
  end
end

AwesomeWorkflow
