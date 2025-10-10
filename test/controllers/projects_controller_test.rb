require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get projects_url
    assert_response :success
  end

  test "should get show" do
    get projects_url(projects(:one))
    assert_response :success
  end

  test "should search projects by query parameter" do
    project = Project.create!(
      ecosystem: 'pypi',
      name: 'numpy',
      package: { 'description' => 'Array computing library' }
    )

    get projects_url, params: { q: 'numpy' }
    assert_response :success
  end

  test "should search projects in ecosystem by query parameter" do
    project = Project.create!(
      ecosystem: 'pypi',
      name: 'test-package',
      package: { 'description' => 'Test description' }
    )

    get projects_ecosystem_url(ecosystem: 'pypi'), params: { q: 'test' }
    assert_response :success
  end

  test "index without search parameter should work" do
    get projects_url
    assert_response :success
  end

  test "ecosystem without search parameter should work" do
    Project.create!(
      ecosystem: 'pypi',
      name: 'test-package',
      package: { 'description' => 'Test description' }
    )

    get projects_ecosystem_url(ecosystem: 'pypi')
    assert_response :success
  end

  test "should show no results message when search returns empty" do
    get projects_url, params: { q: 'nonexistent-project-xyz' }
    assert_response :success
    assert_select '.alert-info', text: /No results found/
    assert_select '.alert-info', text: /nonexistent-project-xyz/
  end

  test "should show no results message for ecosystem search with no matches" do
    Project.create!(
      ecosystem: 'pypi',
      name: 'test-package',
      package: { 'description' => 'Test description' }
    )

    get projects_ecosystem_url(ecosystem: 'pypi'), params: { q: 'nonexistent-xyz' }
    assert_response :success
    assert_select '.alert-info', text: /No results found/
    assert_select '.alert-info', text: /nonexistent-xyz/
  end
end
