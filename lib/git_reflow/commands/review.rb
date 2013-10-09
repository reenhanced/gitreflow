desc 'review will push your latest feature branch changes to your remote repo and create a pull request'
arg_name 'Describe arguments to review here'
flag [:t, :title]
flag [:m, :message]
command :review do |c|
  c.desc 'push your latest feature branch changes to your remote repo and create a pull request against the destination branch'
  c.arg_name '[destination_branch] - the branch you want to merge your feature branch into'
  c.action do |global_options,options,args|
    review_options = {
      'base' => args[0],
      'title' => global_options[:title] || GitReflow.get_first_commit_message,
      'body' => global_options[:message] || global_options[:title]
    }

    GitReflow.review review_options
  end
end
