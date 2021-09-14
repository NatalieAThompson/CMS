ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "fileutils"

require "/home/inunatnat/Documents/CMS/cms.rb"

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  # def create_document(name, content = "")
  #   File.open(File.join(data_path, name), "w") do |file|
  #     file.write(content)
  #   end
  # end

  # def setup
  #   FileUtils.mkdir_p(data_path)

  #   create_document "about.md"
  #   create_document "changes.txt"
  #   create_document "history.txt"
  # end

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

    get last_response["Location"]

    assert_equal 200, last_response.status
    assert_includes last_response.body, "random.txt does not exist"

    get "/"
    refute_includes last_response.body, "random.txt does not exist"
  end

  def test_viewing_markdown_document
    get "/about.md"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Ruby is...</h1>"
  end

  def test_editing_file
    get "/changes.txt/edit"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<button type="submit)
  end

  def test_updating_file
    post "/changes.txt", changes: "New content"

    assert_equal 302, last_response.status

    get last_response["Location"]

    assert_includes last_response.body, "changes.txt has been updated"

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "New content"
  end

  # def test_new
  #   get "/new"

  #   assert_equal 200, last_response.status
  #   assert_includes last_response.body, %q(<button type="submit)
  #   assert_includes last_response.body, %q(id="doc_name)
  # end

  # def teardown
  #   FileUtils.rm_rf(data_path)
  # end
end