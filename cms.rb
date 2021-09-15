require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"
require "redcarpet"
require "fileutils"

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

before do
  @files = Dir.children(data_path)
end

configure do
  enable :sessions
  set :sessions_secret, 'secret'
end

get "/" do
  erb :index
end

def file_exists(name)
  unless @files.include?(name)
    session[:message] = "#{name} does not exist."
    redirect "/"
  end
end

def render_markdown(file)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(file)
end

def load_file(name)
  file = File.read("data/#{name}")
  case File.extname(name)
  when ".txt"
    headers["Content-Type"] = "text/plain"
    file
  when ".md"
    erb render_markdown(file)
  end
end

get "/new" do
  erb :new
end

get "/:name" do |name|
  file_exists(name)
  load_file(name)
end

get "/:name/edit" do |name|
  file_exists(name)
  @file = load_file(name)
  erb :edit
end

EXTENSIONS = %w(.txt .md)

def no_extension(file)
  extension = file.scan(/.(\..+)/)[0]
  if !extension
    file + ".txt"
  elsif !EXTENSIONS.include?(extension[0])
    file.delete_suffix(extension[0]) + ".txt"
  else
    file
  end
end

post "/create" do
  new_file = params[:file_name].strip

  if new_file.empty?
    session[:message] = "A name is required."
    status 422
    erb :new
  else
    file = no_extension(new_file)
    FileUtils.touch File.join(data_path, file)
    session[:message] = "#{file} was created."

    redirect "/"
  end
end

post "/:name" do |name|
  system_path = File.join(data_path, name)
  file_exists(name)
  File.write(system_path, params[:changes])
  session[:message] = "#{name} has been updated."
  redirect("/")
end

