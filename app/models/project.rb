class Project < ApplicationRecord
  has_many :mentions
  has_many :papers, through: :mentions

  # Scopes for science score analysis
  scope :with_science_score, -> { where.not(science_score: nil) }
  scope :high_science_score, -> { where('science_score >= ?', 50) }
  scope :medium_science_score, -> { where('science_score >= ? AND science_score < ?', 20, 50) }
  scope :low_science_score, -> { where('science_score < ?', 20) }
  scope :by_science_score, -> { order(science_score: :desc) }

  def ecosystems_url
    "https://packages.ecosyste.ms/registries/#{registry_url}/packages/#{name}"
  end

  def ecosystems_api_url
    "https://packages.ecosyste.ms/api/v1/registries/#{registry_url}/packages/#{name}"
  end

  def to_s
    "#{ecosystem}: #{name}"
  end

  def description
    return package["description"] if package && package["description"].present?
    return package.dig("repo_metadata", "description") if package && package.dig("repo_metadata", "description").present?
    nil
  end

  def registry_url
    case ecosystem
    when 'cran'
      "cran.r-project.org"
    when 'bioconductor'
      "bioconductor.org"
    when 'pypi'
      "pypi.org"
    end
  end

  def fetch_package_data
    response = Faraday.get(ecosystems_api_url)
    if response.status == 200
      JSON.parse(response.body)
    else
      nil
    end
  rescue
    nil
  end

  def update_package_data
    data = fetch_package_data
    if data
      self.package = data
      # Also fetch commit and readme data for enhanced science scoring
      fetch_enhanced_data
    end
    self.last_synced_at = Time.now
    self.save
  end

  # Enhanced data fetching methods for better science scoring
  def fetch_commit_data
    return unless package && package['repo_metadata'] && package['repo_metadata']['full_name'] && package['repo_metadata']['host']
    
    # Construct the direct API URL using host and full_name
    host_name = package['repo_metadata']['host']['name']
    full_name = package['repo_metadata']['full_name']
    commits_url = "https://commits.ecosyste.ms/api/v1/hosts/#{host_name}/repositories/#{full_name}"
    
    begin
      response = Faraday.get(commits_url)
      if response.status == 200
        data = JSON.parse(response.body)
        self.commits_data = data
        
        # Extract educational emails and store separately
        educational_emails = []
        if data['committers']
          data['committers'].each do |committer|
            email = committer['email']
            if email && educational_email?(email)
              educational_emails << email.downcase
            end
          end
        end
        self.educational_commit_emails = educational_emails.uniq
        save
      else
        puts "HTTP #{response.status} fetching commit data for #{name} from #{commits_url}"
      end
    rescue => e
      puts "Error fetching commit data for #{name}: #{e.message}"
    end
  end

  def fetch_readme_content
    return unless package && package['repo_metadata'] && package['repo_metadata']['download_url']
    
    download_url = package['repo_metadata']['download_url']
    # Try common README filenames
    readme_files = ['README.md', 'README.rst', 'README.txt', 'README', 'readme.md', 'readme.rst']
    
    readme_files.each do |readme_file|
      begin
        archive_url = "https://archives.ecosyste.ms/api/v1/archives/contents?url=#{download_url}&path=#{readme_file}"
        response = Faraday.get(archive_url)
        if response.status == 200
          json = JSON.parse(response.body)
          if json['contents']
            self.readme_content = json['contents']
            save
            return
          end
        end
      rescue => e
        puts "Error fetching README #{readme_file} for #{name}: #{e.message}"
      end
    end
  end

  def educational_email?(email)
    edu_domains = %w[
      .edu .ac.uk .edu.au .ac.in .edu.cn .edu.sg .ac.jp .edu.co .ac.za .edu.mx 
      .edu.my .ac.kr .edu.hk .ac.nz .ac.id .edu.ph .edu.br .ac.th .ac.ir .ac.il
      .ac.at .ac.be .ac.fr .ac.de .ac.it .ac.nl .ac.es .ac.se .ac.ch .ac.dk
      .ac.fi .ac.no .ac.pt .ac.pl .ac.cz .ac.hu .ac.gr .ac.vn
    ]
    
    return false unless email
    email_lower = email.downcase
    
    # Filter out ignored domains (common email providers)
    domain = email_lower.split('@').last
    return false if ignored_email_domains.include?(domain)
    return false if domain.end_with?('.local') || domain.split('.').length == 1
    
    edu_domains.any? { |edu_domain| email_lower.end_with?(edu_domain) }
  end

  def ignored_email_domains
    %w[
      users.noreply.github.com googlemail.com gmail.com hotmail.com outlook.com
      yahoo.com protonmail.com web.de example.com live.com icloud.com hotmail.fr
      yahoo.se yahoo.fr aol.com yandex.com inbox.com mail.com tutanota.com
      fastmail.com zoho.com rocketmail.com sbcglobal.net att.net verizon.net
      comcast.net bellsouth.net charter.net cox.net earthlink.net juno.com
      msn.com rediffmail.com 163.com 126.com qq.com sina.com sohu.com
      naver.com hanmail.net daum.net kakao.com mail.ru yandex.ru rambler.ru
    ]
  end

  def get_educational_commit_emails
    Array(educational_commit_emails || [])
  end

  def get_readme_content
    readme_content || ''
  end

  def commit_email_domains
    return {} unless commits_data && commits_data['committers']
    
    commits_data['committers'].map { |c| 
      email = c['email']
      next unless email
      domain = email.split('@').last&.downcase
      next unless domain
      next if ignored_email_domains.include?(domain)
      next if domain.end_with?('.local') || domain.split('.').length == 1
      [domain, c['count']]
    }.compact.group_by(&:first).transform_values { |v| v.sum(&:last) }
  end

  def educational_commit_domains
    commit_email_domains.select { |domain, _count| 
      edu_domains = %w[
        .edu .ac.uk .edu.au .ac.in .edu.cn .edu.sg .ac.jp .edu.co .ac.za .edu.mx 
        .edu.my .ac.kr .edu.hk .ac.nz .ac.id .edu.ph .edu.br .ac.th .ac.ir .ac.il
        .ac.at .ac.be .ac.fr .ac.de .ac.it .ac.nl .ac.es .ac.se .ac.ch .ac.dk
        .ac.fi .ac.no .ac.pt .ac.pl .ac.cz .ac.hu .ac.gr .ac.vn
      ]
      edu_domains.any? { |edu_domain| domain.end_with?(edu_domain) }
    }
  end

  def repository_owner_record
    package&.dig('repo_metadata', 'owner_record')
  end

  def institutional_owner?
    return false unless repository_owner_record
    
    # Check if it's an organization (more likely to be institutional)
    return false unless repository_owner_record['kind'] == 'organization'
    
    # Check for institutional indicators in various fields
    institutional_indicators = [
      'university', 'college', 'institute', 'institution', 'laboratory', 'lab', 
      'research', 'academic', 'academia', 'school', 'faculty', 'department',
      'center', 'centre', 'consortium', 'foundation', 'society', 'academy',
      'hospital', 'medical', 'clinic', 'health', 'bio', 'genomics', 'biotech',
      'science', 'scientific', 'computational', 'bioinformatics', 'physics',
      'chemistry', 'biology', 'neuroscience', 'ecology', 'environmental',
      'observatory', 'museum', 'library', 'archive', 'data', 'open source',
      'nonprofit', 'non-profit', 'community', 'collaborative', 'consortium'
    ]
    
    # Check owner name, description, and website
    text_to_check = [
      repository_owner_record['name'],
      repository_owner_record['description'],
      repository_owner_record['website'],
      repository_owner_record['login']
    ].compact.join(' ').downcase
    
    institutional_indicators.any? { |indicator| text_to_check.include?(indicator) }
  end

  def academic_owner?
    return false unless repository_owner_record
    
    # Check for academic/educational indicators specifically
    academic_indicators = [
      'university', 'college', 'institute', 'academic', 'academia', 'school', 
      'faculty', 'department', 'research', 'laboratory', 'lab', 'center', 
      'centre', 'observatory', 'museum', 'library', 'archive'
    ]
    
    # Check owner name, description, and website
    text_to_check = [
      repository_owner_record['name'],
      repository_owner_record['description'],
      repository_owner_record['website'],
      repository_owner_record['login']
    ].compact.join(' ').downcase
    
    academic_indicators.any? { |indicator| text_to_check.include?(indicator) }
  end

  def owner_has_educational_website?
    return false unless repository_owner_record
    
    website = repository_owner_record['website']
    return false unless website
    
    # Check if website domain is educational
    begin
      domain = URI.parse(website).host&.downcase
      return false unless domain
      
      edu_domains = %w[
        .edu .ac.uk .edu.au .ac.in .edu.cn .edu.sg .ac.jp .edu.co .ac.za .edu.mx 
        .edu.my .ac.kr .edu.hk .ac.nz .ac.id .edu.ph .edu.br .ac.th .ac.ir .ac.il
        .ac.at .ac.be .ac.fr .ac.de .ac.it .ac.nl .ac.es .ac.se .ac.ch .ac.dk
        .ac.fi .ac.no .ac.pt .ac.pl .ac.cz .ac.hu .ac.gr .ac.vn
      ]
      
      edu_domains.any? { |edu_domain| domain.end_with?(edu_domain) }
    rescue URI::InvalidURIError
      false
    end
  end

  def fetch_enhanced_data
    fetch_commit_data
    fetch_readme_content
    update_science_score!
  end

  def update_science_score!
    breakdown = calculate_science_score_breakdown
    update_column(:science_score, breakdown.final_score)
    breakdown.final_score
  end

  def science_score_breakdown
    # Return cached breakdown if available, otherwise calculate
    return calculate_science_score_breakdown
  end

  class ScienceScoreBreakdown
    attr_reader :final_score, :components

    def initialize
      @final_score = 100
      @components = []
    end

    def add_component(type, description, points, reason = nil)
      @components << {
        type: type, # :base, :bonus, :penalty
        description: description,
        points: points,
        reason: reason
      }
      @final_score += points
    end

    def apply_floor_and_cap
      @final_score = [[@final_score, 0].max, 100].min
    end

    def penalties
      @components.select { |c| c[:type] == :penalty }
    end

    def bonuses
      @components.select { |c| c[:type] == :bonus }
    end

    def base_components
      @components.select { |c| c[:type] == :base }
    end
  end

  def self.update_science_scores_for_top_mentioned(limit = 100)
    projects = Project.where.not(mentions_count: nil)
                     .order(mentions_count: :desc)
                     .limit(limit)
    
    projects.find_each do |project|
      project.update_science_score!
      print "."
    end
    
    puts "\nUpdated science scores for #{projects.count} top mentioned projects"
  end

  def self.update_all_science_scores
    Project.find_each do |project|
      project.update_science_score!
      print "."
    end
    
    puts "\nUpdated science scores for all projects"
  end

  def science_score
    # Use cached value if available, otherwise calculate
    return read_attribute(:science_score) if read_attribute(:science_score)
    calculate_science_score
  end

  def calculate_science_score_breakdown
    return ScienceScoreBreakdown.new.tap { |b| b.add_component(:base, "No package data", -100) } unless package
    return ScienceScoreBreakdown.new.tap { |b| b.add_component(:base, "Empty package data", -100) } if package.empty?

    breakdown = ScienceScoreBreakdown.new
    breakdown.add_component(:base, "Starting score", 0, "All packages start at 100 points")
    
    # Ecosystem penalties
    if ecosystem == 'pypi'
      breakdown.add_component(:penalty, "PyPI ecosystem", -10, "General-purpose ecosystem")
    end
    
    # Well-known scientific packages
    well_known_science_packages = [
      'pymol', 'chimera', 'vmd', 'gromacs', 'amber', 'namd',
      'scipy', 'numpy', 'matplotlib', 'seaborn', 'plotly', 'bokeh',
      'scikit-learn', 'tensorflow', 'pytorch', 'keras', 'theano',
      'pandas', 'jupyter', 'ipython', 'notebook', 'spyder',
      'r-base', 'rstudio', 'shiny', 'ggplot2', 'dplyr', 'tidyr',
      'bioconductor', 'limma', 'edger', 'deseq2', 'tophat', 'bowtie',
      'samtools', 'bcftools', 'bedtools', 'gatk', 'picard', 'star',
      'hisat2', 'kallisto', 'salmon', 'stringtie', 'cufflinks',
      'blast', 'diamond', 'hmmer', 'muscle', 'clustalw', 'mafft',
      'raxml', 'iqtree', 'beast', 'mrbayes', 'phyml', 'paml',
      'plink', 'vcftools', 'admixture', 'structure', 'eigensoft',
      'lme4', 'nlme', 'lavaan', 'sem', 'psych', 'car', 'mass',
      'survival', 'randomforest', 'glmnet', 'gbm', 'xgboost',
      'weka', 'rapidminer', 'orange', 'knime', 'spss', 'stata',
      'circos', 'cytoscape', 'gephi', 'networkx', 'igraph',
      'qgis', 'arcgis', 'grass', 'postgis', 'spatialite',
      'saga', 'gdal', 'proj', 'geos', 'fiona', 'shapely',
      'openstreetmap', 'leaflet', 'folium', 'cartopy', 'basemap'
    ]
    
    package_name_lower = name&.downcase || ''
    is_well_known_science = well_known_science_packages.include?(package_name_lower)
    
    if is_well_known_science
      breakdown.add_component(:bonus, "Well-known science package", 0, "Recognized scientific software")
    end
    
    # Keywords analysis
    keywords = Array(package['keywords'] || package['keywords_array'] || [])
    classifiers = Array(package.dig('metadata', 'classifiers') || [])
    all_keywords = (keywords + classifiers).join(' ').downcase
    
    science_keywords = [
      'scientific', 'science', 'research', 'bioinformatics', 'computational',
      'machine learning', 'data science', 'statistics', 'statistical', 'mathematical',
      'algorithm', 'analysis', 'modeling', 'modelling', 'simulation', 'genomics',
      'proteomics', 'microarray', 'sequencing', 'biostatistics',
      'epidemiology', 'clinical', 'medical', 'pharmaceutical',
      'chemistry', 'physics', 'biology', 'astronomy', 'geology',
      'neural network', 'deep learning', 'artificial intelligence',
      'visualization', 'visualisation', 'plotting', 'numerical', 'optimization',
      'experimental', 'experiment', 'data quality', 'quality control',
      'hydrodynamics', 'dispersive', 'mixed-effects', 'mixed effects',
      'linear models', 'regression', 'molecular', 'structural',
      'visualization', 'graphics', 'grammar of graphics', 'elegant',
      'differential', 'expression', 'microarray', 'pathway',
      'enrichment', 'correlation', 'network', 'ecological', 'ecology',
      'phylogenetic', 'evolutionary', 'genetic', 'variance',
      'multivariate', 'univariate', 'bayesian', 'frequentist'
    ]
    
    keyword_matches = science_keywords.count { |keyword| all_keywords.include?(keyword) }
    if keyword_matches == 0 && !is_well_known_science
      breakdown.add_component(:penalty, "No science keywords", -15, "No scientific terms found in keywords/classifiers")
    elsif keyword_matches > 0
      breakdown.add_component(:bonus, "Science keywords found", 0, "#{keyword_matches} scientific terms in keywords/classifiers")
    end
    
    # Description analysis
    description_text = (package['description'] || '').downcase
    description_matches = science_keywords.count { |keyword| description_text.include?(keyword) }
    if description_matches == 0 && !is_well_known_science
      breakdown.add_component(:penalty, "No science terms in description", -10, "No scientific terms found in description")
    elsif description_matches > 0
      breakdown.add_component(:bonus, "Science terms in description", 0, "#{description_matches} scientific terms in description")
    end
    
    # Academic emails
    maintainers = Array(package['maintainers'] || [])
    academic_domains = [
      '.edu', '.ac.uk', '.ac.jp', '.ac.cn', '.ac.in', '.ac.za', '.ac.nz',
      '.edu.au', '.edu.br', '.edu.mx', '.edu.sg', '.edu.hk', '.edu.tw',
      '.university', '.univ-', '.u-', '.uni-', '.ac.at', '.ac.be', '.ac.fr',
      '.ac.de', '.ac.it', '.ac.nl', '.ac.es', '.ac.se', '.ac.ch', '.ac.dk',
      '.ac.fi', '.ac.no', '.ac.pt', '.ac.pl', '.ac.cz', '.ac.hu', '.ac.gr',
      '.ac.il', '.ac.kr', '.ac.th', '.ac.my', '.ac.id', '.ac.ph', '.ac.vn',
      'mit.edu', 'stanford.edu', 'harvard.edu', 'berkeley.edu', 'caltech.edu',
      'nih.gov', 'nsf.gov', 'nasa.gov', 'cern.ch', 'mpi-', 'cnrs.fr',
      'inria.fr', 'riken.jp', 'aist.go.jp', 'csiro.au', 'nrc-cnrc.gc.ca',
      'posit.co', 'rstudio.com'
    ]
    
    academic_emails = maintainers.count do |maintainer|
      email = maintainer['email']&.downcase || ''
      academic_domains.any? { |domain| email.include?(domain) }
    end
    
    if academic_emails > 0
      breakdown.add_component(:bonus, "Academic maintainer emails", academic_emails * 8, "#{academic_emails} maintainers with academic email addresses")
    end
    
    # Educational commit emails
    educational_commit_emails = get_educational_commit_emails
    if educational_commit_emails.length > 0
      breakdown.add_component(:bonus, "Educational commit emails", educational_commit_emails.length * 20, "#{educational_commit_emails.length} contributors with educational email addresses")
    end
    
    # Repository owner analysis
    if academic_owner?
      breakdown.add_component(:bonus, "Academic repository owner", 20, "Repository owned by academic institution")
    end
    
    if institutional_owner?
      breakdown.add_component(:bonus, "Institutional repository owner", 15, "Repository owned by research institution")
    end
    
    if owner_has_educational_website?
      breakdown.add_component(:bonus, "Educational website", 10, "Repository owner has educational domain website")
    end
    
    # README analysis
    readme_text = get_readme_content.downcase
    
    # Check for science terms in README
    readme_science_matches = science_keywords.count { |keyword| readme_text.include?(keyword) }
    if readme_science_matches > 0
      breakdown.add_component(:bonus, "Science terms in README", readme_science_matches * 2, "#{readme_science_matches} scientific terms found in README")
    end
    
    # DOI patterns
    doi_patterns = [
      /doi\.org\/10\.\d+/,
      /dx\.doi\.org\/10\.\d+/,
      /doi:\s*10\.\d+/,
      /\bdoi\s*[:=]\s*10\.\d+/i
    ]
    
    academic_link_patterns = [
      /arxiv\.org\/abs\/\d+/,
      /pubmed\.ncbi\.nlm\.nih\.gov/,
      /scholar\.google/,
      /researchgate\.net/,
      /orcid\.org\/\d+-\d+-\d+-\d+/,
      /biorxiv\.org\/content/,
      /nature\.com\/articles/,
      /science\.org\/doi/,
      /pnas\.org\/content/,
      /academic\.oup\.com/,
      /springer\.com\/article/,
      /sciencedirect\.com\/science/,
      /ieee\.org\/document/,
      /acm\.org\/doi/
    ]
    
    doi_matches = doi_patterns.count { |pattern| readme_text.match?(pattern) }
    if doi_matches > 0
      breakdown.add_component(:bonus, "DOI references", doi_matches * 10, "#{doi_matches} DOI references found in README")
    end
    
    academic_link_matches = academic_link_patterns.count { |pattern| readme_text.match?(pattern) }
    if academic_link_matches > 0
      breakdown.add_component(:bonus, "Academic links", academic_link_matches * 6, "#{academic_link_matches} academic links found in README")
    end
    
    # CITATION.cff file
    has_citation_file = package.dig('repo_metadata', 'metadata', 'files', 'citation').present?
    if has_citation_file
      breakdown.add_component(:bonus, "CITATION.cff file", 15, "Contains citation file for academic attribution")
    end
    
    # Other research metadata files
    files = package.dig('repo_metadata', 'metadata', 'files') || {}
    
    # CodeMeta file (JSON-LD metadata for research software)
    if files['codemeta'] || files['codemeta.json']
      breakdown.add_component(:bonus, "CodeMeta file", 12, "Contains CodeMeta metadata for research software")
    end
    
    # Zenodo metadata file
    if files['.zenodo.json'] || files['zenodo.json']
      breakdown.add_component(:bonus, "Zenodo metadata", 10, "Contains Zenodo metadata for research archival")
    end
    
    # PublicCode file (used by government/research institutions)
    if files['publiccode.yml'] || files['publiccode.yaml']
      breakdown.add_component(:bonus, "PublicCode file", 8, "Contains PublicCode metadata for institutional software")
    end
    
    # Research institution maintainers
    research_institutions = [
      'university', 'institute', 'laboratory', 'lab', 'research', 'academy',
      'college', 'school', 'faculty', 'department', 'center', 'centre',
      'foundation', 'postdoc', 'phd', 'professor', 'researcher', 'scientist'
    ]
    
    institution_matches = maintainers.count do |maintainer|
      profile_text = [
        maintainer['name'],
        maintainer['url'],
        maintainer['email']
      ].compact.join(' ').downcase
      
      research_institutions.any? { |term| profile_text.include?(term) }
    end
    
    if institution_matches > 0
      breakdown.add_component(:bonus, "Research institution maintainers", institution_matches * 5, "#{institution_matches} maintainers with research institution indicators")
    end
    
    # Negative indicators
    non_science_keywords = [
      'social media', 'facebook', 'twitter', 'instagram', 'linkedin', 'tiktok',
      'e-commerce', 'shopping', 'payment', 'billing', 'cryptocurrency', 'blockchain',
      'gaming', 'game', 'entertainment', 'music', 'video streaming', 'media player',
      'chat', 'messaging', 'email client', 'calendar', 'todo', 'task management',
      'website', 'web design', 'cms', 'blog', 'wordpress', 'drupal',
      'mobile app', 'ios', 'android', 'react native', 'flutter',
      'marketing', 'advertising', 'seo', 'analytics', 'tracking',
      'business', 'crm', 'erp', 'hr', 'payroll', 'accounting',
      'utility', 'system tool', 'file manager', 'backup', 'cleaner',
      'web framework', 'web application', 'web development', 'website builder',
      'template', 'templating', 'scaffold', 'scaffolding', 'boilerplate',
      'starter kit', 'project template', 'code generator', 'web server',
      'http server', 'rest api', 'web service', 'microservice'
    ]
    
    all_text = [
      package['description'],
      package['name'],
      Array(package['keywords'] || package['keywords_array'] || []).join(' '),
      package.dig('repo_metadata', 'description')
    ].compact.join(' ').downcase
    
    non_science_matches = non_science_keywords.count { |keyword| all_text.include?(keyword) }
    if non_science_matches > 0
      breakdown.add_component(:penalty, "Non-science indicators", non_science_matches * -25, "#{non_science_matches} non-scientific terms found")
    end
    
    # Corporate indicators
    corporate_indicators = [
      'microsoft corporation', 'google llc', 'facebook inc', 'apple inc',
      'amazon web services', 'adobe', 'oracle', 'salesforce', 'intuit',
      'reserved by', 'trademark', 'proprietary', 'commercial license'
    ]
    
    corporate_matches = corporate_indicators.count { |indicator| all_text.include?(indicator) }
    if corporate_matches > 0
      breakdown.add_component(:penalty, "Corporate indicators", corporate_matches * -30, "#{corporate_matches} corporate/proprietary indicators found")
    end
    
    breakdown.apply_floor_and_cap
    breakdown
  end

  def calculate_science_score
    return 0 unless package
    return 0 if package.empty?  # No package metadata found = not a real package = not science

    score = 100  # Start from 100 and subtract points for non-science indicators
    
    # Ecosystem penalties - reduce score for general-purpose ecosystems
    score -= 10 if ecosystem == 'pypi'
    # No penalty for CRAN (science-oriented) or Bioconductor (specifically scientific)
    
    # Well-known scientific packages get a bonus (keep at 100)
    well_known_science_packages = [
      'pymol', 'chimera', 'vmd', 'gromacs', 'amber', 'namd',
      'scipy', 'numpy', 'matplotlib', 'seaborn', 'plotly', 'bokeh',
      'scikit-learn', 'tensorflow', 'pytorch', 'keras', 'theano',
      'pandas', 'jupyter', 'ipython', 'notebook', 'spyder',
      'r-base', 'rstudio', 'shiny', 'ggplot2', 'dplyr', 'tidyr',
      'bioconductor', 'limma', 'edger', 'deseq2', 'tophat', 'bowtie',
      'samtools', 'bcftools', 'bedtools', 'gatk', 'picard', 'star',
      'hisat2', 'kallisto', 'salmon', 'stringtie', 'cufflinks',
      'blast', 'diamond', 'hmmer', 'muscle', 'clustalw', 'mafft',
      'raxml', 'iqtree', 'beast', 'mrbayes', 'phyml', 'paml',
      'plink', 'vcftools', 'admixture', 'structure', 'eigensoft',
      'lme4', 'nlme', 'lavaan', 'sem', 'psych', 'car', 'mass',
      'survival', 'randomforest', 'glmnet', 'gbm', 'xgboost',
      'weka', 'rapidminer', 'orange', 'knime', 'spss', 'stata',
      'circos', 'cytoscape', 'gephi', 'networkx', 'igraph',
      'qgis', 'arcgis', 'grass', 'postgis', 'spatialite',
      'saga', 'gdal', 'proj', 'geos', 'fiona', 'shapely',
      'openstreetmap', 'leaflet', 'folium', 'cartopy', 'basemap'
    ]
    
    package_name_lower = name&.downcase || ''
    is_well_known_science = well_known_science_packages.include?(package_name_lower)
    
    # Keywords/classifiers scoring - penalize for lack of science keywords
    keywords = Array(package['keywords'] || package['keywords_array'] || [])
    classifiers = Array(package.dig('metadata', 'classifiers') || [])
    all_keywords = (keywords + classifiers).join(' ').downcase
    
    science_keywords = [
      'scientific', 'science', 'research', 'bioinformatics', 'computational',
      'machine learning', 'data science', 'statistics', 'statistical', 'mathematical',
      'algorithm', 'analysis', 'modeling', 'modelling', 'simulation', 'genomics',
      'proteomics', 'microarray', 'sequencing', 'biostatistics',
      'epidemiology', 'clinical', 'medical', 'pharmaceutical',
      'chemistry', 'physics', 'biology', 'astronomy', 'geology',
      'neural network', 'deep learning', 'artificial intelligence',
      'visualization', 'visualisation', 'plotting', 'numerical', 'optimization',
      'experimental', 'experiment', 'data quality', 'quality control',
      'hydrodynamics', 'dispersive', 'mixed-effects', 'mixed effects',
      'linear models', 'regression', 'molecular', 'structural',
      'visualization', 'graphics', 'grammar of graphics', 'elegant',
      'differential', 'expression', 'microarray', 'pathway',
      'enrichment', 'correlation', 'network', 'ecological', 'ecology',
      'phylogenetic', 'evolutionary', 'genetic', 'variance',
      'multivariate', 'univariate', 'bayesian', 'frequentist'
    ]
    
    keyword_matches = science_keywords.count { |keyword| all_keywords.include?(keyword) }
    # Penalize for lack of science keywords (unless it's a well-known science package)
    score -= 15 if keyword_matches == 0 && !is_well_known_science
    
    # Description scoring - penalize for lack of science terms in description
    description_text = (package['description'] || '').downcase
    description_matches = science_keywords.count { |keyword| description_text.include?(keyword) }
    score -= 10 if description_matches == 0 && !is_well_known_science
    
    # Email domain scoring for academic institutions - keep points for academic emails
    maintainers = Array(package['maintainers'] || [])
    academic_domains = [
      '.edu', '.ac.uk', '.ac.jp', '.ac.cn', '.ac.in', '.ac.za', '.ac.nz',
      '.edu.au', '.edu.br', '.edu.mx', '.edu.sg', '.edu.hk', '.edu.tw',
      '.university', '.univ-', '.u-', '.uni-', '.ac.at', '.ac.be', '.ac.fr',
      '.ac.de', '.ac.it', '.ac.nl', '.ac.es', '.ac.se', '.ac.ch', '.ac.dk',
      '.ac.fi', '.ac.no', '.ac.pt', '.ac.pl', '.ac.cz', '.ac.hu', '.ac.gr',
      '.ac.il', '.ac.kr', '.ac.th', '.ac.my', '.ac.id', '.ac.ph', '.ac.vn',
      'mit.edu', 'stanford.edu', 'harvard.edu', 'berkeley.edu', 'caltech.edu',
      'nih.gov', 'nsf.gov', 'nasa.gov', 'cern.ch', 'mpi-', 'cnrs.fr',
      'inria.fr', 'riken.jp', 'aist.go.jp', 'csiro.au', 'nrc-cnrc.gc.ca',
      'posit.co', 'rstudio.com'  # Add R/data science companies
    ]
    
    academic_emails = maintainers.count do |maintainer|
      email = maintainer['email']&.downcase || ''
      academic_domains.any? { |domain| email.include?(domain) }
    end
    # Keep bonus for academic emails (strong positive indicator)
    score += academic_emails * 8
    
    # Enhanced commit email domain scoring - keep bonus for educational commits
    educational_commit_emails = get_educational_commit_emails
    score += educational_commit_emails.length * 20  # Strong weight for educational commit emails
    
    # Repository owner analysis - keep bonuses for institutional ownership
    score += 20 if academic_owner?  # Strong indicator for academic ownership
    score += 15 if institutional_owner?  # Broader institutional ownership
    score += 10 if owner_has_educational_website?  # Educational domain website
    
    # README and repository metadata scoring - keep bonuses for academic indicators
    readme_text = get_readme_content.downcase
    
    # Check for science terms in README
    readme_science_matches = science_keywords.count { |keyword| readme_text.include?(keyword) }
    score += readme_science_matches * 2
    
    # DOI and academic link patterns
    doi_patterns = [
      /doi\.org\/10\.\d+/,
      /dx\.doi\.org\/10\.\d+/,
      /doi:\s*10\.\d+/,
      /\bdoi\s*[:=]\s*10\.\d+/i
    ]
    
    academic_link_patterns = [
      /arxiv\.org\/abs\/\d+/,
      /pubmed\.ncbi\.nlm\.nih\.gov/,
      /scholar\.google/,
      /researchgate\.net/,
      /orcid\.org\/\d+-\d+-\d+-\d+/,
      /biorxiv\.org\/content/,
      /nature\.com\/articles/,
      /science\.org\/doi/,
      /pnas\.org\/content/,
      /academic\.oup\.com/,
      /springer\.com\/article/,
      /sciencedirect\.com\/science/,
      /ieee\.org\/document/,
      /acm\.org\/doi/
    ]
    
    doi_matches = doi_patterns.count { |pattern| readme_text.match?(pattern) }
    score += doi_matches * 10  # Keep bonus for DOIs
    
    academic_link_matches = academic_link_patterns.count { |pattern| readme_text.match?(pattern) }
    score += academic_link_matches * 6  # Keep bonus for academic links
    
    # CITATION.cff file presence - strong indicator of scientific software
    has_citation_file = package.dig('repo_metadata', 'metadata', 'files', 'citation').present?
    score += 15 if has_citation_file  # Keep significant boost for citation files
    
    # Other research metadata files
    files = package.dig('repo_metadata', 'metadata', 'files') || {}
    
    # CodeMeta file (JSON-LD metadata for research software)
    score += 12 if files['codemeta'] || files['codemeta.json']
    
    # Zenodo metadata file
    score += 10 if files['.zenodo.json'] || files['zenodo.json']
    
    # PublicCode file (used by government/research institutions)
    score += 8 if files['publiccode.yml'] || files['publiccode.yaml']
    
    # Owner/maintainer profile analysis
    research_institutions = [
      'university', 'institute', 'laboratory', 'lab', 'research', 'academy',
      'college', 'school', 'faculty', 'department', 'center', 'centre',
      'foundation', 'postdoc', 'phd', 'professor', 'researcher', 'scientist'
    ]
    
    institution_matches = maintainers.count do |maintainer|
      profile_text = [
        maintainer['name'],
        maintainer['url'],
        maintainer['email']
      ].compact.join(' ').downcase
      
      research_institutions.any? { |term| profile_text.include?(term) }
    end
    score += institution_matches * 5  # Keep bonus for institutional maintainers
    
    # Heavy penalties for clearly non-science packages
    non_science_keywords = [
      'social media', 'facebook', 'twitter', 'instagram', 'linkedin', 'tiktok',
      'e-commerce', 'shopping', 'payment', 'billing', 'cryptocurrency', 'blockchain',
      'gaming', 'game', 'entertainment', 'music', 'video streaming', 'media player',
      'chat', 'messaging', 'email client', 'calendar', 'todo', 'task management',
      'website', 'web design', 'cms', 'blog', 'wordpress', 'drupal',
      'mobile app', 'ios', 'android', 'react native', 'flutter',
      'marketing', 'advertising', 'seo', 'analytics', 'tracking',
      'business', 'crm', 'erp', 'hr', 'payroll', 'accounting',
      'utility', 'system tool', 'file manager', 'backup', 'cleaner',
      'web framework', 'web application', 'web development', 'website builder',
      'template', 'templating', 'scaffold', 'scaffolding', 'boilerplate',
      'starter kit', 'project template', 'code generator', 'web server',
      'http server', 'rest api', 'web service', 'microservice'
    ]
    
    all_text = [
      package['description'],
      package['name'],
      Array(package['keywords'] || package['keywords_array'] || []).join(' '),
      package.dig('repo_metadata', 'description')
    ].compact.join(' ').downcase
    
    non_science_matches = non_science_keywords.count { |keyword| all_text.include?(keyword) }
    score -= non_science_matches * 25  # Increased penalty for non-science indicators
    
    # Heavy penalty for corporate/proprietary packages
    corporate_indicators = [
      'microsoft corporation', 'google llc', 'facebook inc', 'apple inc',
      'amazon web services', 'adobe', 'oracle', 'salesforce', 'intuit',
      'reserved by', 'trademark', 'proprietary', 'commercial license'
    ]
    
    corporate_matches = corporate_indicators.count { |indicator| all_text.include?(indicator) }
    score -= corporate_matches * 30  # Heavy penalty for corporate packages
    
    # Ensure score doesn't go below 0 and cap at 100
    [[score, 0].max, 100].min
  end
end
