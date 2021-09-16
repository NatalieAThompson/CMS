ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "fileutils"

# require "/home/inunatnat/Documents/CMS/cms.rb"
require_relative "../cms"

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def setup
    FileUtils.mkdir_p(data_path)

    create_document "about.md"
    create_document "changes.txt"
    create_document "history.txt"
  end

  def session
    last_request.env["rack.session"]
  end

  def admin_session
    { "rack.session" => { username: "admin", signed_in: true } }
  end

  def test_index
      get "/"

      assert_equal(200, last_response.status)
      assert_includes(last_response.body, "about.md")
      assert_includes(last_response.body, "changes.txt")
      assert_includes(last_response.body, "history.txt")
      assert(last_response)
  end

  def test_file_page
    get "/history.txt"

    assert_equal(200, last_response.status)
    assert_equal("text/plain", last_response["Content-Type"])
    assert_includes(last_response.body, "Ruby 0.95 released")
  end

  def test_unknown_file
    get "/random.txt"

    assert_equal(302, last_response.status)
    assert_equal "random.txt does not exist.", session[:message]
    get last_response["Location"]
  end

  def test_viewing_markdown_document
    get "/about.md"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Ruby is...</h1>"
  end

  def must_be_signed_in
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_editing_file
    get "/changes.txt/edit"
    assert_equal 302, last_response.status
    must_be_signed_in

    get "/changes.txt/edit", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<button type="submit)
  end

  def test_updating_file
    post "/changes.txt", changes: "New content"
    must_be_signed_in

    post "/changes.txt", {changes: "New content"}, admin_session

    assert_equal 302, last_response.status
    assert_equal "changes.txt has been updated.", session[:message]

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "New content"
  end

  def test_new
    get "/new"
    assert_equal 302, last_response.status
    must_be_signed_in

    get "/new", {}, admin_session
    assert_equal 200, last_response.status
    assert_includes last_response.body, %q(<button type="submit)
    assert_includes last_response.body, %q(id="doc_name)
  end

  def test_new_empty_file_name
    post "/create", {file_name: ""}, admin_session

    assert_equal 422, last_response.status
    assert_includes last_response.body, %q(A name is required.</p>)
  end

  def new_file_naming(name)
    post "/create", {file_name: name}
    must_be_signed_in

    post "/create", {file_name: name}, admin_session
    assert_equal 302, last_response.status
    assert_equal "hello.txt was created.", session[:message]

    get "/"
    assert_includes last_response.body, "hello.txt"
  end

  def test_new_file_bad_naming
    new_file_naming("hello")
  end

  def test_new_file_bad_extension
    new_file_naming("hello.alkf")
  end

  def test_new_file
   new_file_naming("hello.txt")
  end

  def test_deleteing_file
    get "/"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "Delete</button>"

    post "/changes.txt/delete"
    must_be_signed_in

    post "/changes.txt/delete", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal "changes.txt was deleted.", session[:message]

    get "/"
    refute_includes last_response.body, %q(href="/changes.txt)
  end

  def test_signed_out
    get "/"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "Sign In"
  end

  def test_sign_in_route
    get "/sign_in"

    assert_equal 200, last_response.status
    assert_includes last_response.body, %q(name="username)
    assert_includes last_response.body, %q(name="password)
    assert_includes last_response.body, "Sign In</button>"
  end

  def test_signing_in_success_as_admin
    post "/sign_in", username: "natalie", password: "password"
    assert_equal 302, last_response.status
    assert_equal "Welcome!", session[:message]
    assert_equal "natalie", session[:username]

    get last_response["location"]

    assert_equal 200, last_response.status
    assert_includes last_response.body, "Welcome!"
    assert_includes last_response.body, %q(Sign out</button>)

    get "/"
    refute_includes last_response.body, "Welcome!"
  end

  def test_signing_in_success_as_user
    post "/sign_in", username: "natalie", password: "password"
    assert_equal 302, last_response.status
    assert_equal "Welcome!", session[:message]
    assert_equal "natalie", session[:username]

    get last_response["location"]
    assert_includes last_response.body, "Welcome!"
  end

  def test_signing_in_fail
    post "/sign_in", username: "blah", password: "la"

    assert_equal 422, last_response.status
    assert_nil session[:username]
    assert_includes last_response.body, "Invalid Credentials"
    assert_includes last_response.body, %q(value=blah)
  end

  def test_signing_out
    get "/", {}, admin_session

    post "/sign_out"
    assert_equal 302, last_response.status
    assert_equal "You have been signed out.", session[:message]

    get last_response["location"]
    assert_nil session[:username]
    assert_includes last_response.body, "Sign In"
  end

  def test_sets_session_value
    get "/"

    assert_equal false, session["signed_in"]
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end
end