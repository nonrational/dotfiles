require 'irb/ext/save-history'
IRB.conf[:SAVE_HISTORY] = 1000
IRB.conf[:HISTORY_FILE] = "#{ENV['HOME']}/.irb-save-history"

def _h
  puts irb_history.join("\n")
end

def irb_history(count = nil)
  hist = Readline::HISTORY.to_a

  if count
    len = hist.length
    from = len - count
    from = 0 if from < 0
    puts "len: #{len}, count: #{count}, from: #{from}, hist.class: #{hist.class}, hist.length: #{hist.length}"

    hist[from..-1]
  else
    hist
  end
end

require 'securerandom'
require 'base64'
