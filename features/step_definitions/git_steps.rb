Given /^the global git config exists$/ do
  step %{an empty file named "#{ENV['HOME']}/.gitconfig"}
end

Then /^we should see the reflow alias in the global git config$/ do
  step %{the file "#{ENV['HOME']}/.gitconfig" should contain "reflow = !./git-reflow"}
end
