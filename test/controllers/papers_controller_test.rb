require "test_helper"

class PapersControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get papers_url
    assert_response :success
  end

  test "should get show" do
    get paper_url(papers(:one))
    assert_response :success
  end
end
