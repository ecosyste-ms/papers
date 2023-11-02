class Project < ApplicationRecord
  has_many :mentions
  has_many :papers, through: :mentions

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
    return package["description"] if package
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
    end
    self.last_synced_at = Time.now
    self.save
  end
end
