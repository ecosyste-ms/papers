require "test_helper"

class Api::V1::ProjectsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get api_v1_projects_url
    assert_response :success
  end

  test "should search projects by query parameter" do
    project = Project.create!(
      ecosystem: 'pypi',
      name: 'numpy',
      package: { 'description' => 'Array computing library' }
    )

    get api_v1_projects_url, params: { q: 'numpy' }
    assert_response :success
  end

  test "should search projects in ecosystem by query parameter" do
    project = Project.create!(
      ecosystem: 'pypi',
      name: 'test-package',
      package: { 'description' => 'Test description' }
    )

    get api_v1_projects_ecosystem_url(ecosystem: 'pypi'), params: { q: 'test' }
    assert_response :success
  end

  test "index without search parameter should work" do
    get api_v1_projects_url
    assert_response :success
  end

  test "ecosystem without search parameter should work" do
    Project.create!(
      ecosystem: 'pypi',
      name: 'test-package',
      package: { 'description' => 'Test description' }
    )

    get api_v1_projects_ecosystem_url(ecosystem: 'pypi')
    assert_response :success
  end
end
