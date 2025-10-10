require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  test "science_score returns 0 for projects without package data" do
    project = Project.new(ecosystem: 'pypi', name: 'test')
    assert_equal 0, project.science_score
  end

  test "science_score returns 0 for projects with empty package data" do
    project = Project.new(ecosystem: 'pypi', name: 'test', package: {})
    assert_equal 0, project.science_score
  end

  test "science_score returns base score for different ecosystems" do
    # Starting from 100, with penalties for lack of science indicators
    bioconductor_project = Project.new(ecosystem: 'bioconductor', package: {'name' => 'test'})
    # 100 - 15 (no keywords) - 10 (no description) = 75
    assert_equal 75, bioconductor_project.science_score

    cran_project = Project.new(ecosystem: 'cran', package: {'name' => 'test'})
    # 100 - 15 (no keywords) - 10 (no description) = 75
    assert_equal 75, cran_project.science_score

    pypi_project = Project.new(ecosystem: 'pypi', package: {'name' => 'test'})
    # 100 - 10 (PyPI penalty) - 15 (no keywords) - 10 (no description) = 65
    assert_equal 65, pypi_project.science_score
  end

  test "science_score avoids penalties for science keywords" do
    project = Project.new(
      ecosystem: 'pypi',
      package: {
        'keywords' => ['machine learning', 'data science'],
        'description' => 'A scientific computing library for bioinformatics research'
      }
    )
    
    # Base 100 - 10 (PyPI penalty) = 90
    # No penalty for keywords (has science keywords)
    # No penalty for description (has science terms)
    assert_equal 90, project.science_score
  end

  test "science_score works with classifiers" do
    project = Project.new(
      ecosystem: 'pypi',
      package: {
        'metadata' => {
          'classifiers' => ['Topic :: Scientific/Engineering', 'Topic :: Scientific/Engineering :: Bio-Informatics']
        }
      }
    )
    
    # Base 100 - 10 (PyPI penalty) = 90
    # No penalty for keywords (has science classifiers)
    # -10 penalty for no description = 80
    assert_equal 80, project.science_score
  end

  test "science_score with academic email domains" do
    project = Project.new(
      ecosystem: 'pypi',
      package: {
        'maintainers' => [
          { 'email' => 'researcher@mit.edu', 'name' => 'Dr. Smith' },
          { 'email' => 'admin@company.com', 'name' => 'John Doe' }
        ]
      }
    )
    
    # Base 100 - 10 (PyPI penalty) - 15 (no keywords) - 10 (no description) = 65
    # + 8 (academic email) + 5 (institution match) = 78
    assert_equal 78, project.science_score
  end

  test "science_score with DOI and academic links" do
    project = Project.new(
      ecosystem: 'pypi',
      package: {'name' => 'test'},
      readme_content: 'Please cite our paper: https://doi.org/10.1038/nature12345 and see our preprint at https://arxiv.org/abs/2301.12345'
    )
    
    # Base 100 - 10 (PyPI penalty) - 15 (no keywords) - 10 (no description) = 65
    # + 10 (DOI) + 6 (academic link) = 81
    assert_equal 81, project.science_score
  end

  test "science_score with CITATION.cff file" do
    project = Project.new(
      ecosystem: 'pypi',
      package: {
        'repo_metadata' => {
          'metadata' => {
            'files' => {
              'citation' => 'CITATION.cff'
            }
          }
        }
      }
    )
    
    # Base 100 - 10 (PyPI penalty) - 15 (no keywords) - 10 (no description) = 65
    # + 15 (citation file) = 80
    assert_equal 80, project.science_score
  end

  test "science_score with research institution maintainers" do
    project = Project.new(
      ecosystem: 'pypi',
      package: {
        'maintainers' => [
          { 'name' => 'Professor Jane Smith', 'email' => 'jane@example.com' },
          { 'name' => 'Research Institute Team', 'email' => 'team@corp.com' }
        ]
      }
    )
    
    # Base 100 - 10 (PyPI penalty) - 15 (no keywords) - 10 (no description) = 65
    # + 10 (institution matches 2 * 5) = 75
    assert_equal 75, project.science_score
  end

  test "science_score caps at 100" do
    project = Project.new(
      ecosystem: 'bioconductor',
      package: {
        'keywords' => ['scientific', 'research', 'bioinformatics', 'computational', 'machine learning'] * 5,
        'description' => 'scientific research bioinformatics computational machine learning data science statistics mathematical algorithm analysis modeling simulation genomics proteomics microarray sequencing biostatistics epidemiology clinical medical pharmaceutical chemistry physics biology astronomy geology neural network deep learning artificial intelligence visualization plotting numerical optimization',
        'maintainers' => [
          { 'email' => 'prof@harvard.edu', 'name' => 'Professor Research' },
          { 'email' => 'scientist@mit.edu', 'name' => 'Dr. University Lab' }
        ],
        'repo_metadata' => {
          'readme' => 'Our research paper: https://doi.org/10.1038/nature12345 and preprint https://arxiv.org/abs/2301.12345'
        }
      }
    )
    
    assert_equal 100, project.science_score
  end

  test "science_score should be low for clearly non-science packages" do
    # Excel package - data manipulation tool, not science
    excel_project = Project.new(
      ecosystem: 'pypi',
      name: 'excel',
      package: {
        'description' => 'This package name is reserved by Microsoft Corporation',
        'keywords' => [],
        'repo_metadata' => {
          'description' => 'xlrd excel read wrapper'
        }
      }
    )
    
    # Base 100 - 10 (PyPI) - 15 (no science keywords) - 10 (no science description) = 65
    # - 60 (corporate penalty: "microsoft corporation" + "reserved by" = 2 * 30) = 5
    assert_equal 5, excel_project.science_score
    
    # Facebook SDK - social media tool, not science
    facebook_project = Project.new(
      ecosystem: 'pypi',
      name: 'facebook-sdk',
      package: {
        'description' => 'Python SDK for Facebook\'s Graph API',
        'keywords' => ['facebook', 'sdk', 'api', 'social'],
        'repo_metadata' => {
          'description' => 'Facebook SDK for Python'
        }
      }
    )
    
    # Base 100 - 10 (PyPI) - 15 (no science keywords) - 10 (no science description) = 65
    # - 25 (social media penalty: "social media" = 1 * 25) = 40
    assert_equal 40, facebook_project.science_score
  end

  test "description falls back to repo_metadata description" do
    # Test with package description
    project_with_package_desc = Project.new(
      package: {
        'description' => 'Package description',
        'repo_metadata' => {
          'description' => 'Repo description'
        }
      }
    )
    assert_equal 'Package description', project_with_package_desc.description

    # Test fallback to repo_metadata description
    project_with_repo_desc = Project.new(
      package: {
        'description' => nil,
        'repo_metadata' => {
          'description' => 'Repo description'
        }
      }
    )
    assert_equal 'Repo description', project_with_repo_desc.description

    # Test with empty package description
    project_with_empty_desc = Project.new(
      package: {
        'description' => '',
        'repo_metadata' => {
          'description' => 'Repo description'
        }
      }
    )
    assert_equal 'Repo description', project_with_empty_desc.description

    # Test with no descriptions
    project_with_no_desc = Project.new(
      package: {
        'repo_metadata' => {}
      }
    )
    assert_nil project_with_no_desc.description
  end

  test "institutional_owner? detects academic/institutional ownership" do
    # Test academic owner
    academic_project = Project.new(
      ecosystem: 'pypi',
      package: {
        'repo_metadata' => {
          'owner_record' => {
            'kind' => 'organization',
            'name' => 'The Love Lab',
            'description' => 'Software produced by members of the Love Lab (UNC-Chapel Hill)',
            'website' => 'https://mikelove.github.io',
            'login' => 'thelovelab'
          }
        }
      }
    )
    assert academic_project.institutional_owner?
    assert academic_project.academic_owner?

    # Test institutional owner (broader)
    institutional_project = Project.new(
      ecosystem: 'pypi',
      package: {
        'repo_metadata' => {
          'owner_record' => {
            'kind' => 'organization',
            'name' => 'CellProfiler',
            'description' => 'Software for quantitative analysis of biological images',
            'website' => 'http://cellprofiler.org/',
            'login' => 'CellProfiler'
          }
        }
      }
    )
    assert institutional_project.institutional_owner?
    assert_not institutional_project.academic_owner?

    # Test non-institutional owner
    personal_project = Project.new(
      ecosystem: 'pypi',
      package: {
        'repo_metadata' => {
          'owner_record' => {
            'kind' => 'user',
            'name' => 'John Doe',
            'description' => 'Just a regular developer',
            'website' => 'https://johndoe.com',
            'login' => 'johndoe'
          }
        }
      }
    )
    assert_not personal_project.institutional_owner?
    assert_not personal_project.academic_owner?
  end

  test "owner_has_educational_website? detects educational domains" do
    # Test educational website
    edu_project = Project.new(
      ecosystem: 'pypi',
      package: {
        'repo_metadata' => {
          'owner_record' => {
            'kind' => 'user',
            'name' => 'Robert Castelo',
            'description' => 'biostatistics, machine learning, genetics, genomics',
            'website' => 'https://functionalgenomics.upf.edu',
            'login' => 'rcastelo'
          }
        }
      }
    )
    assert edu_project.owner_has_educational_website?

    # Test non-educational website
    non_edu_project = Project.new(
      ecosystem: 'pypi',
      package: {
        'repo_metadata' => {
          'owner_record' => {
            'kind' => 'user',
            'name' => 'John Doe',
            'website' => 'https://johndoe.com',
            'login' => 'johndoe'
          }
        }
      }
    )
    assert_not non_edu_project.owner_has_educational_website?
  end

  test "science_score includes owner analysis" do
    # Test with academic owner
    academic_project = Project.new(
      ecosystem: 'pypi',
      package: {
        'repo_metadata' => {
          'owner_record' => {
            'kind' => 'organization',
            'name' => 'The Love Lab',
            'description' => 'Software produced by members of the Love Lab (UNC-Chapel Hill)',
            'website' => 'https://mikelove.github.io',
            'login' => 'thelovelab'
          }
        }
      }
    )
    
    # Base 100 - 10 (PyPI) - 15 (no keywords) - 10 (no description) = 65
    # + 15 (institutional owner) + 20 (academic owner) = 100
    assert_equal 100, academic_project.science_score
  end

  test "well-known science packages avoid penalties" do
    # NumPy - well-known science package
    numpy_project = Project.new(
      ecosystem: 'pypi',
      name: 'numpy',
      package: {
        'description' => 'Fundamental package for array computing',
        'keywords' => []
      }
    )
    
    # Base 100 - 10 (PyPI) = 90 (no penalties for lack of science keywords/description)
    assert_equal 90, numpy_project.science_score
    
    # Unknown package with no science indicators
    unknown_project = Project.new(
      ecosystem: 'pypi',
      name: 'unknown-package',
      package: {
        'description' => 'Some random package',
        'keywords' => []
      }
    )
    
    # Base 100 - 10 (PyPI) - 15 (no science keywords) - 10 (no science description) = 65
    assert_equal 65, unknown_project.science_score
  end

  test "CRAN and Bioconductor packages get no ecosystem penalty" do
    # CRAN package
    cran_project = Project.new(
      ecosystem: 'cran',
      name: 'test-package',
      package: {
        'description' => 'Some R package',
        'keywords' => []
      }
    )
    
    # Base 100 - 15 (no science keywords) - 10 (no science description) = 75
    assert_equal 75, cran_project.science_score
    
    # Bioconductor package - investigate the actual scoring
    bioconductor_project = Project.new(
      ecosystem: 'bioconductor',
      name: 'test-package',
      package: {
        'description' => 'Some bioinformatics package',
        'keywords' => []
      }
    )
    
    # Let's see what the actual score is and understand the breakdown
    actual_score = bioconductor_project.science_score
    
    # Debug: Check if "bioinformatics" is detected as a science keyword
    # Base 100 - 15 (no science keywords) + 0 (has "bioinformatics" in description) = 85
    # The description should prevent the -10 penalty
    assert_equal 85, actual_score, "Bioconductor score should be 85 (100 - 15 for no keywords, but no description penalty due to 'bioinformatics')"
  end

  test "investigate science keyword detection" do
    # Test if "bioinformatics" is properly detected
    project_with_bioinformatics = Project.new(
      ecosystem: 'pypi',
      name: 'test',
      package: {
        'description' => 'A bioinformatics tool',
        'keywords' => []
      }
    )

    # Should not get description penalty due to "bioinformatics"
    # Base 100 - 10 (PyPI) - 15 (no keywords) + 0 (has science term in description) = 75
    assert_equal 75, project_with_bioinformatics.science_score

    # Test with science keywords
    project_with_keywords = Project.new(
      ecosystem: 'pypi',
      name: 'test',
      package: {
        'description' => 'Regular description',
        'keywords' => ['bioinformatics', 'scientific']
      }
    )

    # Should not get keyword penalty due to science keywords
    # Base 100 - 10 (PyPI) + 0 (has science keywords) - 10 (no science description) = 80
    assert_equal 80, project_with_keywords.science_score
  end

  test "search finds projects by name" do
    project = Project.create!(
      ecosystem: 'pypi',
      name: 'numpy',
      package: { 'description' => 'Array computing library' }
    )

    results = Project.search('numpy')
    assert_includes results, project

    results = Project.search('nump')
    assert_includes results, project
  end

  test "search finds projects by ecosystem" do
    project = Project.create!(
      ecosystem: 'pypi',
      name: 'test-package',
      package: { 'description' => 'Test package' }
    )

    results = Project.search('pypi')
    assert_includes results, project
  end

  test "search finds projects by description" do
    project = Project.create!(
      ecosystem: 'pypi',
      name: 'test-package',
      package: { 'description' => 'bioinformatics analysis tool' }
    )

    results = Project.search('bioinformatics')
    assert_includes results, project

    results = Project.search('analysis')
    assert_includes results, project
  end

  test "search finds projects by repo metadata description" do
    project = Project.create!(
      ecosystem: 'pypi',
      name: 'test-package',
      package: {
        'description' => 'Simple package',
        'repo_metadata' => { 'description' => 'advanced genomics tool' }
      }
    )

    results = Project.search('genomics')
    assert_includes results, project
  end

  test "search is case insensitive" do
    project = Project.create!(
      ecosystem: 'pypi',
      name: 'NumPy',
      package: { 'description' => 'Array Computing Library' }
    )

    assert_includes Project.search('numpy'), project
    assert_includes Project.search('NUMPY'), project
    assert_includes Project.search('NuMpY'), project
    assert_includes Project.search('array'), project
    assert_includes Project.search('ARRAY'), project
  end

  test "search returns all projects when query is blank" do
    project1 = Project.create!(
      ecosystem: 'pypi',
      name: 'test1',
      package: { 'description' => 'Test 1' }
    )
    project2 = Project.create!(
      ecosystem: 'cran',
      name: 'test2',
      package: { 'description' => 'Test 2' }
    )

    results = Project.search('')
    assert_includes results, project1
    assert_includes results, project2

    results = Project.search(nil)
    assert_includes results, project1
    assert_includes results, project2
  end

  test "search returns empty when no matches" do
    Project.create!(
      ecosystem: 'pypi',
      name: 'test-package',
      package: { 'description' => 'Test package' }
    )

    results = Project.search('nonexistent-term-xyz')
    assert_equal 0, results.count
  end
end
