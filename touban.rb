# coding: utf-8
require 'sinatra'
require "sinatra/reloader" if development?
require 'active_record'

require 'byebug' if development?
require 'haml'
require 'pony'

require "sinatra/config_file"

enable :sessions
set :session_secret, "My session secret"

ActiveRecord::Base.establish_connection(
    adapter: 'sqlite3',
    database: "db/development.sqlite3"
)

#グループごとのDB
class Group < ActiveRecord::Base
end

#ユーザーごとのDB
class User < ActiveRecord::Base
end

use Rack::MethodOverride

class MainApp < Sinatra::Base
  configure :development do
    register Sinatra::Reloader
  end

  configure :development do
    register Sinatra::ConfigFile
    config_file 'config.yml'
    settings.path_prefix = ''
  end

  configure :production do
    register Sinatra::ConfigFile
    config_file 'config.yml'
  end


  before do
    @path_prefix = settings.path_prefix
  end

  get '/' do
    groups = Group.all
    @grouplist = []
    @namelist = []
    @minilist = []
    @idlist = []
    daylist = []
    @daylist = []
    @interlist = []
    @nillist = []
    #トップに表示するユーザ3人をグループごとに決定
    groups.each do |group|
      tmporder = group.noworder
      users = User.where(:groupid => group.id.to_s).sort_by{|user| user.order}
      if users.size == 0
        @nillist.push(true)
      else
        @nillist.push(false)
      end
      #byebug if development?
      size = 3
      num = 0
      tmplist = []
      daylist = []
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
      if group.interval > 1
        day -= 24*60*60*7*(group.interval - 1)
      end
      4.times() do
        d = day.year.to_s + "/" + "%02d" % day.month.to_s  + "/" + "%02d" % day.day.to_s
        daylist.push(d)
        day += 24*60*60*7
      end
      @daylist.push(daylist)
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
    nowuser = User.where(:groupid => group[0].id.to_s, :order => group[0].noworder)
    if group[0].interval != 1
      Pony.mail :to => nowuser[0].email,
                :from => 'hirai@mm.media.kyoto-u.ac.jp',
                :subject => '【' + group[0].name + '】完了しました',
                :body => nowuser[0].name + "さん
" + group[0].name + "の当番完了を受理しました。
ご苦労様でした。"
    end
    if group[0].interval == 0
      group[0].interval = 1
    elsif group[0].interval == 2
      group[0].interval = 0
      group[0].noworder += 1
      users = User.where(:groupid => group[0].id.to_s).sort_by{|user| user.order}
      if users.size <= group[0].noworder
        group[0].noworder = 0
      end
      nextuser = User.where(:groupid => group[0].id.to_s, :order => group[0].noworder)
      Pony.mail :to => nextuser[0].email,
                :from => 'hirai@mm.media.kyoto-u.ac.jp',
                :subject => '【' + group[0].name + '】今週の当番のお知らせ',
                :body => nextuser[0].name + "さん
" + group[0].name + "の今週の掃除当番をお願いします。
掃除の内容については，美濃研マニュアルを参照してください．

終わりましたら、当番表のページhttp://kusk.mm.media.kyoto-u.ac.jp/roster/
にアクセスして、完了ボタンを押してください。
(※完了ボタンを押さないと遅延扱いになります！)


R412の掃除---------------------------------
1:ゴミ袋がまんぱんになれば捨てに行きます.
2:月，木曜日にみんなのゴミを集めます.
3:金曜日に掃除機をかけます.


キッチンの掃除-----------------------------
1: ゴミ捨て
  ・三角コーナー、排水口のゴミ
  ・ゴミ箱のゴミ
  ・新聞
　　　ある程度たまったら紐で結んで束にして下さい．

2:机と床の掃除
  ・机の上
　　　布巾で拭き、布巾はきれいに洗って干しておいてください。
　・床
　　　掃除機をかけ、「フロアクイックル」でみがいて下さい

-------------------------------------------"
    end

    group[0].save
    redirect "#{@path_prefix}/"
    #debug
  end


  #当番変更タイミングでの処理
  get '/schedule/renew/' do
    groups = Group.all
    groups.each do |group|
      if group.interval == 0
        group.interval = 2
      elsif group.interval == 1
        group.interval = 0
        group.noworder += 1
      else
        group.interval += 1
      end
      users = User.where(:groupid => group.id.to_s).sort_by{|user| user.order}
      if users.size <= group.noworder
        group.noworder = 0
      end
      group.save
      #メール送信のアレ
      nowuser = User.where(:groupid => group.id.to_s, :order => group.noworder)
      #ちゃんとやってる時
      if group.interval == 0
        title = '【' + group.name + '】今週の当番のお知らせ'
        tientitle = ""
      else
        title = '【' + group.name + '】今週の当番のお知らせ【遅延】'
        tientitle = "
前回担当から遅延していますので、早急に掃除を行ってください。
"
      end
      Pony.mail :to => nowuser[0].email,
                :from => 'hirai@mm.media.kyoto-u.ac.jp',
                :subject => title,
                :body => nowuser[0].name + "さん
" + group.name + "の今週の掃除当番をお願いします。
"+ tientitle + "
掃除の内容については，美濃研マニュアルを参照してください．

終わりましたら、当番表のページhttp://kusk.mm.media.kyoto-u.ac.jp/roster/
にアクセスして、完了ボタンを押してください。
(※完了ボタンを押さないと遅延扱いになります！)


R412の掃除---------------------------------
1:ゴミ袋がまんぱんになれば捨てに行きます.
2:月，木曜日にみんなのゴミを集めます.
3:金曜日に掃除機をかけます.


キッチンの掃除-----------------------------
1: ゴミ捨て
  ・三角コーナー、排水口のゴミ
  ・ゴミ箱のゴミ
  ・新聞
　　　ある程度たまったら紐で結んで束にして下さい．

2:机と床の掃除
  ・机の上
　　　布巾で拭き、布巾はきれいに洗って干しておいてください。
　・床
　　　掃除機をかけ、「フロアクイックル」でみがいて下さい

-------------------------------------------"
    end
    redirect "#{@path_prefix}/"
  end

  post '/' do
    #  title = "登板スクリプト"
    group = Group.new(:name => params[:name],:mini => params[:mini],:interval => 0,:renew => 0,:noworder => 0)
    group.save
    redirect "#{@path_prefix}/"
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
    redirect "#{@path_prefix}/"
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
    Pony.mail :to => params[:email],
              :from => 'hirai@mm.media.kyoto-u.ac.jp',
              :subject => '【' + @name + '】登録完了しました。',
              :body => params[:name] + "さん
" + @name + "へのユーザー登録が完了しました。"
    redirect "#{@path_prefix}/config/" + params[:id]
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
    redirect "#{@path_prefix}/config/" + params[:groupid]
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
    redirect "#{@path_prefix}/config/" + params[:groupid]
  end

  #ポインタの現在値を変更
  get '/config/point/:groupid/:pointid' do
    group = Group.where(:id => params[:groupid])
    group[0].noworder = params[:pointid]
    group[0].save
    redirect "#{@path_prefix}/config/" + params[:groupid]
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
    redirect "#{@path_prefix}/config/" + params[:groupid]
  end

  #グループの削除
  post '/deletegroup/:groupid' do
    group = Group.where(:id => params[:groupid])
    if params[:pass] == "Pnd#Li4!"
      group[0].destroy
      redirect "#{@path_prefix}/"
    else
      redirect "#{@path_prefix}/config/" + params[:groupid]
    end
  end
end