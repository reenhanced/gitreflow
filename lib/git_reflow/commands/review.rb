desc 'review will push your latest feature branch changes to your remote repo and create a pull request'
arg_name 'Describe arguments to review here'
command :review do |c|
  c.desc 'push your latest feature branch changes to your remote repo and create a pull request against the destination branch'
  c.arg_name '[destination_branch] - the branch you want to merge your feature branch into'
  c.action do |global_options,options,args|
    review_options = {'base' => nil, 'title' => nil, 'body' => nil}
    case args.length
    when 3
      review_options['base'] = args[0]
      review_options['title'] = args[1]
      review_options['body'] = args[2]
    when 2
      review_options['base'] = args[0]
      review_options['title'] = args[1]
      review_options['body'] = review_options['title']
    when 1
      review_options['base'] = args[0]
      review_options['title'] = review_options['body'] = GitReflow.get_first_commit_message
    else
      review_options['title'] = review_options['body'] = GitReflow.get_first_commit_message
    end
    GitReflow.review review_options
  end
end
