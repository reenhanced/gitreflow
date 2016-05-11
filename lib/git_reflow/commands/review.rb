desc 'review will push your latest feature branch changes to your remote repo and create a pull request'
arg_name 'Describe arguments to review here'
command :review do |c|
  c.desc 'push your latest feature branch changes to your remote repo and create a pull request against the destination branch'
  c.arg_name '[destination_branch] - the branch you want to merge your feature branch into'
  c.flag [:t, :title]
  c.flag [:m, :message]
  c.action do |global_options,options,args|
    if options[:title] || options[:message]
      review_options = {
        :base => args[0],
        :title => options[:title],
        :body =>  options[:message]
      }
    else
      review_options = { :base => args[0] }
    end

    GitReflow.review(review_options)
  end
end
