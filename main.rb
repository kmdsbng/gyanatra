#!/usr/local/bin/ruby -Ku

require 'rubygems'
require 'sinatra/base'
require 'digest/md5'
require 'sdbm'
require 'pstore'
require 'date'
require 'haml'
require File.join(File.dirname(__FILE__), 'config')


module DataStore
  PAGE_LIMIT = 10

  def transaction
    db = PStore.new(DB_FILE)
    db.transaction {
      yield(db)
    }
  end

  def save(data)
    transaction {|db|
      db[:items] ||= []
      db[:items].unshift(data)
    }
  end

  def load_all
    transaction {|db|
      db[:items] || []
    }
  end

  def load_page(page)
    index = page - 1
    all = load_all
    start = index * PAGE_LIMIT
    stop = start + PAGE_LIMIT
    all[start...stop] || []
  end
end

class MyApp < Sinatra::Base
  include DataStore

  set :public, File.dirname(__FILE__) + '/public'

  get '/' do
    'Hello world!'
  end

  get '/list' do
    do_list
  end

  post '/upload' do
    do_upload
  end

  def do_list
    @page = (params[:page] || 1).to_i
    @items = load_page(@page)
    haml :list
  end

  def do_upload
    id = params[:id]
    imagedata = params[:imagedata]
    hash = Digest::MD5.hexdigest(imagedata)

    dbm = SDBM.open(ID_FILE, 0644)
    dbm[hash] = id
    dbm.close

    save_item(id, hash)

    File.open(File.join(IMAGE_DIR, "#{hash}.png"), 'w') {|f|
      f.sync = true
      f.write(imagedata)
    }
    convert_to_image_url(hash)
  end

  def convert_to_image_url(hash)
    "http://#{HOST}:#{PORT}/image/#{hash}.png"
  end

  def save_item(id, hash)
    save(:id => id, :hash => hash, :date => DateTime.now)
  end
end

MyApp.run! :host => 'localhost', :port => PORT



