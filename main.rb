#! /usr/bin/ruby

require "discordrb"

infractions = {}

def process_message(content, time, infractions)
  match = content.match(/(7656\d{8}\d+|\d{8}\d+(?=@discord))/)
  return 0 unless match
  number = match[1].to_i & 0xFFFFFFFF
  if infractions[number]
    infractions[number] << time
  else
    infractions[number] = [time]
  end
  return infractions[number].size
end

def parse_id(content)
  match = content.match(/\d{8}\d+/)
  return "0" unless match
  return match[0]
end

def process_history(channel, infractions)
  infractions.clear
  last = nil
  cutoff = Time.now - 60*60*24*30
  length = 0
  loop do
    messages = channel.history(100, last)
    messages.each do |message|
      next if message.author.current_bot?
      process_message(message.content, message.timestamp, infractions)
    end
    length += messages.size
    break if messages.last.timestamp < cutoff
    last = messages.last.id
  end
  puts "Loaded #{length} messages from #{channel}"
end

bot = Discordrb::Bot.new token: ARGV[0] # TOKEN

channel = nil

if File.exists? ".banbot.config"
  File.open(".banbot.config", "r") do |f|
    channel = f.read.strip
  end
else
  channel = "ban-reports"
end

bot.ready do 
  process_history(bot.servers.values[0].channels.select{|c|c.name == channel}.first, infractions)
end

bot.message do |event|
  content = event.message.content
  if event.channel.name == channel
    times = process_message(content, Time.now, infractions)
    if times > 1
      event.message.reply "#{event.message.author.mention}, user `#{parse_id(content)}` has been banned **#{times}** times in the past month."
    end
  end
  if content.start_with?("banchannel->")
    author = event.author
    if author.is_a? Discordrb::Member
      if author.permission?(:manage_server)
        channel = content.split(" ")[1]
        File.open(".banbot.config", "w") do |f|
          f.write(channel)
        end
        event.message.reply "Set watched channel to #{channel}"
      end
    end
  end
end

bot.run
