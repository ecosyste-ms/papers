class Project < ApplicationRecord
  has_many :mentions
  has_many :papers, through: :mentions

  def ecosystems_url
    "https://packages.ecosyste.ms/registries/#{registry_url}/packages/#{name}"
  end

  def to_s
    "#{ecosystem}: #{name}"
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
end
