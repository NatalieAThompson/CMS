require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"
require "redcarpet"
require "fileutils"
require "yaml"
require "bcrypt"

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

before do
  @files = Dir.children(data_path)
  session[:signed_in] ||= false
end

configure do
  enable :sessions
  set :sessions_secret, 'secret'
end

get "/" do
  erb :index
end

get "/sign_in" do
  erb :login
end

get "/sign_up" do
  erb :sign_up
end

def load_users
  yamlfile = File.read(load_user_credentials)
  users = YAML.load(yamlfile)
end

def load_user_credentials
  credentials_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/configuration.yaml", __FILE__)
  else
    File.expand_path("../configuration.yaml", __FILE__)
  end
end

def check_login_yaml?(username, password)
  users = load_users
  users.keys.include?(username) && BCrypt::Password.new(users[username]) == password
end

post "/sign_in" do
  if check_login_yaml?(params[:username], params[:password])
    session[:signed_in] = true
    session[:username] = params[:username]
    session[:message] = "Welcome!"
    redirect "/"
  else
    session[:message] = "Invalid Credentials"
    status 422
    erb :login
  end
end

post "/sign_out" do
  session[:signed_in] = false
  session.delete(:username)
  session[:message] = "You have been signed out."

  redirect "/"
end

def unique_username?(new_user)
  users = load_users
  users.none? do |user, _|
    user == new_user
  end
end

def passwords_match?(password, password_confirm)
  password == password_confirm
end

def format_into_yaml(hash)
  str = "{"
  hash.each do |name, password|
    str << "#{name}: #{password},"
  end
  str + "}"
end

post "/sign_up" do
  if !unique_username?(params[:username])
    session[:message] = "Username is taken."
    erb :sign_up
  elsif !passwords_match?(params[:password], params[:password_confirm])
    session[:message] = "The passwords did not match."
    erb :sign_up
  else
    password = BCrypt::Password.create(params[:password])
    users = load_users
    users.merge!(params[:username] => password)
    File.write(load_user_credentials, format_into_yaml(users))
    session[:message] = "You should be able to sign in."
    redirect "/sign_in"
  end
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

def not_signed_in
  session[:message] = "You must be signed in to do that."
  redirect "/"
end

get "/new" do
  if session[:signed_in]
    erb :new
  else
    not_signed_in
  end
end

get "/:name" do |name|
  file_exists(name)
  load_file(name)
end

get "/:name/edit" do |name|
  if session[:signed_in]
    file_exists(name)
    @file = load_file(name)
    erb :edit
  else
    not_signed_in
  end
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
  if session[:signed_in]
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
  else
    not_signed_in
  end
end

post "/:name" do |name|
  if session[:signed_in]
    system_path = File.join(data_path, name)
    file_exists(name)
    File.write(system_path, params[:changes])
    session[:message] = "#{name} has been updated."
    redirect("/")
  else
    not_signed_in
  end
end

post "/:name/delete" do |name|
  if session[:signed_in]
    File.delete(File.join(data_path, name))
    session[:message] = "#{name} was deleted."

    redirect "/"
  else
    not_signed_in
  end
end

def is_digit?(character)
  character =~ /[0-9]/
end

post "/:name/duplicate" do |name|
  if session[:signed_in]
    file = name.split(".")

    matching_named_files = @files.select do |each_file|
      each_file.include?(file[0][0...-1])
    end

    largest_num = 0

    matching_named_files.each do |each_file|
      find_num = each_file.scan(/(\d+)./).flatten[0].to_i || 0
      if find_num > largest_num
        largest_num = find_num
      end
    end

    if is_digit?(file[0][-1])
      file[0] = file[0].chars
      file[0].pop
      file[0] = file[0].join + (largest_num + 1).to_s
    else
      file[0] = file[0] + (largest_num + 1).to_s
    end
    file = file.join(".")

    FileUtils.touch File.join(data_path, file)
    session[:message] = "#{name} was duplicated as #{file}."

    redirect "/"
  else
    not_signed_in
  end
end

get "/upload/image" do
  erb :image
end

post "/upload/image" do
  if params[:file]
    p params[:file][:filename]
    # filename = params[:image][:filename]
    # tempfile = params[:image][:tempfile]
    # target = "../data/#{filename}"

    # File.open(target, 'wb') {|f| f.write tempfile.read }
  end

end

