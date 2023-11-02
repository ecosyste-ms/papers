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

  def openalex_api_url
    "https://api.openalex.org/works/#{doi_url}?mailto=andrew@ecosyste.ms"
  end

  def fetch_openalex_data
    response = Faraday.get(openalex_api_url)
    if response.status == 200
      JSON.parse(response.body)
    else
      nil
    end
  rescue
    nil
  end

  def update_openalex_data
    data = fetch_openalex_data
    if data
      self.openalex_data = data
      self.title = data["title"]
      self.publication_date = data["publication_date"]
      self.openalex_id = data["id"]
    end
    self.last_synced_at = Time.now
    self.save
  end
end
