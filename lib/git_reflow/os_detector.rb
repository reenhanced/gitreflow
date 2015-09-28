# Thanks to http://stackoverflow.com/questions/170956/how-can-i-find-which-operating-system-my-ruby-program-is-running-on
# and to Thoughtbot: https://github.com/thoughtbot/cocaine/blob/master/lib/cocaine/os_detector.rb
module GitReflow
  class OSDetector
    def windows?
      (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil
    end

    def mac?
      (/darwin/ =~ RUBY_PLATFORM) != nil
    end

    def unix?
      !OS.windows?
    end

    def linux?
      OS.unix? and not OS.mac?
    end
  end

  OS = OSDetector.new
end
