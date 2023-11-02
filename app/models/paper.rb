class Paper < ApplicationRecord
  has_many :mentions
  has_many :projects, through: :mentions

  def to_param
    doi
  end

  def to_s
    doi
  end

  def doi_url
    "https://doi.org/#{doi}"
  end
end
