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

  test "should accept valid sort parameters" do
    get papers_url, params: { sort: "title", order: "asc" }
    assert_response :success
  end

  test "should handle multiple valid sort parameters" do
    get papers_url, params: { sort: "title,mentions_count", order: "asc,desc" }
    assert_response :success
  end

  test "should reject SQL injection attempts in sort parameter" do
    get papers_url, params: { sort: "'; DROP TABLE papers; --", order: "asc" }
    assert_response :success
    assert Paper.exists?, "Papers table should still exist after SQL injection attempt"
  end

  test "should reject SQL injection attempts in order parameter" do
    get papers_url, params: { sort: "title", order: "'; DROP TABLE papers; --" }
    assert_response :success
    assert Paper.exists?, "Papers table should still exist after SQL injection attempt"
  end

  test "should ignore invalid sort columns and use default" do
    get papers_url, params: { sort: "invalid_column", order: "asc" }
    assert_response :success
  end

  test "should ignore invalid order directions and use default" do
    get papers_url, params: { sort: "title", order: "invalid_order" }
    assert_response :success
  end
end
