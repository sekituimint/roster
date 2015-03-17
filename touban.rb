# coding: utf-8
require 'sinatra'
require 'sinatra/base'
require "sinatra/reloader" if development?
require 'active_record'

require 'byebug'
require 'haml'
require 'pony'

register Sinatra::Reloader

enable :sessions
set :session_secret, "My session secret"

ActiveRecord::Base.establish_connection(
    adapter: 'sqlite3',
    database: 'db/development.sqlite3'
)

#グループごとのDB
class Group < ActiveRecord::Base
end

#ユーザーごとのDB
class User < ActiveRecord::Base
end

use Rack::MethodOverride



class MainApp < Sinatra::Base
  get '/' do
    groups = Group.all
    @grouplist = []
    @namelist = []
    @minilist = []
    @idlist = []
    @daylist = []
    @interlist = []
    #トップに表示するユーザ3人をグループごとに決定
    groups.each do |group|
      tmporder = group.noworder
      users = User.where(:groupid => group.id.to_s).sort_by{|user| user.order}
      size = 3
      num = 0
      tmplist = []
      while num != size do
        tmplist.push(users[tmporder])
        tmporder += 1
        if tmporder == users.size
          tmporder = 0
        end
        num += 1
      end
      #時間の取得
      day = Time.now
      while day.wday != 1 do
        day -= 24*60*60
      end
      4.times do
        d = day.year.to_s + "/" + "%02d" % day.month.to_s  + "/" + "%02d" % day.day.to_s
        @daylist.push(d)
        day += 24*60*60*7
      end
      @grouplist.push(tmplist)
      @namelist.push(group.name)
      @minilist.push(group.mini)
      @idlist.push(group.id)
      @interlist.push(group.interval)
    end
    haml :top
  end

  #おそうじ完了時
  get '/kanryou/:id' do
    group = Group.where(:id => params[:id])
    group[0].interval = 1
    group[0].save
    redirect '/'
  end

  post '/' do
    #  title = "登板スクリプト"
    group = Group.new(:name => params[:name],:mini => params[:mini],:interval => 0,:renew => 0,:noworder => 0)
    group.save
    redirect '/'
  end

  get '/atarashiihyou' do
    haml :newhyou
  end

  get '/groups/:id' do
    group = Group.where(:id => params[:id])
    @name = group[0].name
    haml :groupdetail
  end

  #コンフィグ画面
  get '/config/:id' do
    #ナビバー表示用
    groups = Group.all
    @namelist = []
    @minilist = []
    @idlist = []
    groups.each do |group|
      @namelist.push(group.name)
      @minilist.push(group.mini)
      @idlist.push(group.id)
    end

    group = Group.where(:id => params[:id])
    @users = User.where(:groupid => params[:id]).sort_by{|user| user.order}
    @name = group[0].name
    @noworder = group[0].noworder
    @groupid = group[0].id
    @id = group[0].id
    haml :groupconfig
  end

  get '/sendmail' do
    Pony.mail :to => 'hirai@mm.media.kyoto-u.ac.jp',
              :from => 'hirai@mm.media.kyoto-u.ac.jp',
              :subject => 'Howdy, Partna!'
    redirect '/'
  end

  #新規ユーザ登録後戻ってくる画面
  post '/config/:id' do
    group = Group.where(:id => params[:id])
    beforeusers = User.where(:groupid => params[:id]).sort_by{|user| user.order}
    adduser = User.new(:name => params[:name],:email => params[:email],:groupid => params[:id],:order => beforeusers.size)
    adduser.save
    @users = User.where(:groupid => params[:id]).sort_by{|user| user.order}
    @name = group[0].name
    @noworder = group[0].noworder
    @groupid = group[0].id
    @id = group[0].id
    redirect '/config/' + params[:id]
  end

  #上と順番を変更
  get '/config/up/:groupid/:upid' do
    group = Group.where(:id => params[:groupid])
    usersita = User.where(:groupid => params[:groupid],:order => params[:upid])
    userue = User.where(:groupid => params[:groupid],:order => params[:upid].to_i - 1)

    tmp = usersita[0].order
    usersita[0].order = userue[0].order
    userue[0].order = tmp
    usersita[0].save
    userue[0].save
    #ポインタあるときの移動
    if usersita[0].order == group[0].noworder
      group[0].noworder = userue[0].order
      group[0].save
    else
      if userue[0].order == group[0].noworder
        group[0].noworder = usersita[0].order
        group[0].save
      end
    end
    redirect '/config/' + params[:groupid]
  end

  #下と順番を変更
  get '/config/down/:groupid/:upid' do
    group = Group.where(:id => params[:groupid])
    userue = User.where(:groupid => params[:groupid],:order => params[:upid])
    usersita = User.where(:groupid => params[:groupid],:order => params[:upid].to_i + 1)
    tmp = usersita[0].order
    usersita[0].order = userue[0].order
    userue[0].order = tmp
    usersita[0].save
    userue[0].save
    #ポインタあるときの移動
    if usersita[0].order == group[0].noworder
      group[0].noworder = userue[0].order
      group[0].save
    else
      if userue[0].order == group[0].noworder
        group[0].noworder = usersita[0].order
        group[0].save
      end
  end
    redirect '/config/' + params[:groupid]
  end

  #ポインタの現在値を変更
  get '/config/point/:groupid/:pointid' do
    group = Group.where(:id => params[:groupid])
    group[0].noworder = params[:pointid]
    group[0].save
    redirect '/config/' + params[:groupid]
  end

  #ユーザーの削除
  get '/config/delete/:groupid/:deleteid' do
    group = Group.where(:id => params[:groupid])
    deleteuser = User.where(:groupid => params[:groupid],:order => params[:deleteid])
    deleteuser[0].destroy
    users = User.where(:groupid => params[:groupid])
    users.each do  |user|
      if user.order > params[:deleteid].to_i
        user.order = user.order - 1
        user.save
      end
    end
    redirect '/config/' + params[:groupid]
  end
end