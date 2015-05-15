desc 'review will push your latest feature branch changes to your remote repo and create a pull request'
arg_name 'Describe arguments to review here'
command :review do |c|
  c.desc 'push your latest feature branch changes to your remote repo and create a pull request against the destination branch'
  c.arg_name '[destination_branch] - the branch you want to merge your feature branch into'
  c.flag [:t, :title], default_value: 'last commit message'
  c.flag [:m, :message], default_value: 'title'
  c.action do |global_options,options,args|
    git_root_dir = run('git rev-parse --show-toplevel').strip
    pull_request_msg_file = "#{git_root_dir}/.git/GIT_REFLOW_PR_MSG"

    if global_options[:title] || global_options[:message]
      review_options = {
        'base' => args[0],
        'title' => (global_options[:title]   || GitReflow.current_branch),
        'body' =>  global_options[:message]
      }
    else
      File.open(pull_request_msg_file, 'w') do |file|
        file.write(GitReflow.current_branch)
      end
      GitReflow.run("$EDITOR #{pull_request_msg_file}", with_system: true)
      pr_msg = File.open(pull_request_msg_file).each_line.map(&:strip).to_a
      File.delete(pull_request_msg_file)
      title = pr_msg.shift
      unless pr_msg.empty? 
        pr_msg.shift if pr_msg.first.empty?
      end
      review_options = {'base' => args[0],'title' => title,'body' =>  pr_msg.join("\n")}
    end

    puts "\nReview your PR:\n"
    puts "--------\n"
    puts "Title:\n#{review_options['title']}\n\n"
    puts "Body:\n#{review_options['body']}\n"
    puts "--------\n"
    GitReflow.review(review_options) unless ask("Submit pull request? (Y)") =~ /n/i
  end
end
