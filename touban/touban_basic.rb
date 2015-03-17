# coding: utf-8
require 'sinatra'
require "sinatra/reloader" if development?

require 'haml'

def hash2html(hash)
  html = []
  for key, val in hash do
    html << "<#{key}> #{val*3} </#{key}>"
  end

  html.join("\n")
end

#login認証のためのHelper
helpers do
  def protected!
    unless authorized?
      response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
      throw(:halt, [401, "Not authorized\n"])
    end
  end
  def authorized?
    @auth ||=  Rack::Auth::Basic::Request.new(request.env)
    @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == ['name', 'passwd']
  end
end



get '/' do
  hash = { "fname"=>"hirai", :sname => "souhei",  age: 23}
  print hash
  puts hash
  hash2html(hash)
  @title = "登板スクリプト"
  haml :top
end

get '/home' do
  protected!
  "認証されたユーザーのみ閲覧できる"
  
end


get '/' do
  hash = { "fname"=>"hirai", :sname => "souhei",  age: 23}

  print hash
  puts hash
  hash2html(hash)
  @title = "登板スクリプト"
  haml :top
end



get '/add_member/:member' do |member|
  member_file = "#{settings.root}/members.dat"
  `touch #{member_file}` if !File.exist?(member_file)
  members = File.open(member_file).read.split("\n")

  if members.include?(member) then
    return "#{member} is already our member!"
  end
  members << member
  
  members.sort!
  #members = members.sort
  fout = File.open(member_file,'w')
  fout.puts members.join("\n")
  fout.close

  "new member #{member}!"
end

get '/member_list' do
  members = []
  File.open("#{settings.root}/members.dat").each{|line|
    members << line.strip
  }
  members.join("\n")
end
