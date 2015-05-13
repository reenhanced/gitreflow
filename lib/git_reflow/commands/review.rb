desc 'review will push your latest feature branch changes to your remote repo and create a pull request'
arg_name 'Describe arguments to review here'
command :review do |c|
  c.desc 'push your latest feature branch changes to your remote repo and create a pull request against the destination branch'
  c.arg_name '[destination_branch] - the branch you want to merge your feature branch into'
  c.flag [:t, :title], default_value: 'last commit message'
  c.flag [:m, :message], default_value: 'title'
  c.flag [:e, :edit], default_value: "edit the auto generated commit"
  c.action do |global_options,options,args|

    commit_msg_file = '/tmp/git_reflow_pr_msg'

    if global_options[:title] || global_options[:message]
      review_options = {
        'base' => args[0],
        'title' => (global_options[:title]   || GitReflow.get_first_commit_message),
        'body' =>  (global_options[:message] || GitReflow.get_first_commit_message)
      }
      edit = false
    else # if edit or nothing provided, open editor
      edit = true
    end

    if global_options[:edit]
      File.open(commit_msg_file, 'w') do |file|
        file.write(GitReflow.get_first_commit_message)
      end
    end

    if edit
      system('nano', commit_msg_file)
      pr_msg = File.open(commit_msg_file).lines.map(&:strip).to_a
      title = pr_msg.take(1)
      File.delete('/tmp/reflow_pr_msg')
      review_options = {
        'base' => args[0],
        'title' => title,
        'body' =>  pr_msg
      }
    end

    GitReflow.review review_options
  end
end
