require 'rubygems'
require 'sinatra'  
require 'data_mapper'
require 'pony' # email support
require 'resolv' # email validation


SITE_TITLE = "Grocerizer"  
SITE_DESCRIPTION = "the amazing grocery list"   

# setup database

DataMapper::setup(:default, "sqlite3://#{Dir.pwd}/grocerize.db") # create new sql3 database
  
class Item # creates table called 'Notes'
  include DataMapper::Resource  
  property :id, Serial
  property :name, String, :required => true  
  property :amt, Integer, :default => 1
end  
  
DataMapper.finalize.auto_upgrade! # update the db when we make any changes

helpers do  # escape XSS
    include Rack::Utils  
    alias_method :h, :escape_html  # can now call h(some_value)
end  

get '/' do  
  @items = Item.all :order => :id.desc  
  @title = 'Items'  
  @count = Item.count
  erb :home  
end  

get '/clearall' do
  Item.all.destroy
  DataMapper.auto_migrate!
  redirect '/'
end  

post '/' do  
  item = Item.new  
  text=params[:text]
  get_fields(item, text)
  puts "amt: " + item.amt.to_s
  puts "name: " + item.name
  puts "saved? " + item.save.to_s
  check_existing(item)
  redirect '/'  
end  

get '/send' do
  @title = "Email List"
  erb :send
end

post '/send' do
  if !validate_email_domain(params[:email])
    redirect '/invalidemail'
  else
    body = create_email
    Pony.mail :to => params[:email],
              :from => 'grocerizer@gmail.com',
              :subject => 'Grocery List for #{Time.now.strftime("%d/%m/%Y")}',
              :subject => body,
    redirect '/emailsent'
  end
end

get '/emailsent' do
  @title = 'Email Sent!'
  erb :emailsent
end

get '/invalidemail' do
  @title = "Oops!"
  erb :invalidemail
end

get '/:id' do  # whenever we area passed an :id key, we want to edit the note
  @item = Item.get params[:id]  
  @title = "Edit Item"  
  erb :edit  
end  

put '/:id' do # 'put' is a RESTful way to update our db 
  n = Item.get params[:id]  
  n.name = params[:name]  
  n.amt = params[:amt]  
  n.save  
  redirect '/'  
end  

get '/:id/delete' do  
  @item = Item.get params[:id]  
  @title = "Confirm Deletion of #{@item.name}"  
  erb :delete  
end 

delete '/:id' do  
  n = Item.get params[:id]  
  n.destroy  
  redirect '/'  
end 

get '/:id/inc' do  
  n = Item.get params[:id]  
  n.amt += 1
  n.save  
  redirect '/'  
end  

get '/:id/dec' do  
  n = Item.get params[:id]  
  n.amt -= 1
  n.save
  if n.amt<= 0
    n.destroy
  end
  redirect '/'  
end

# helper methods

def get_fields(item, text)
  item.amt = text.match(/^a/) ? 1 : text.match(/^[0-9]*/)[0].to_i
  item.amt = 1 if item.amt == 0
  item.name = text.match(/[A-Za-z\s]*$/).to_s.lstrip.gsub(item.amt.to_s,"")
  item.name.gsub!(/^a /,"")
end

def check_existing(item)
  existing = Item.first(:name => item.name)
  if existing!=nil && existing!=item
    existing.amt += item.amt
    existing.save
    item.destroy
  end
end

def create_email
  string = ""
  items = Item.all
  items.each do |item|
    string += item.amt.to_s + " " + item.name + "\n" 
  end
  return string
end

def validate_email_domain(email)
  return false if !email.match(/\@(.+)/)
  domain = email.match(/\@(.+)/)[1]
  return false if domain == nil
  Resolv::DNS.open do |dns|
      @mx = dns.getresources(domain, Resolv::DNS::Resource::IN::MX)
  end
  @mx.size > 0 ? true : false
end