require 'open-uri'

class Paper < ApplicationRecord
  has_many :mentions
  has_many :projects, through: :mentions

  scope :with_openalex_id, -> { where.not(openalex_id: nil) }
  
  scope :without_urls, -> { where(urls: []) }
  scope :with_urls, -> { where.not(urls: []) }

  def self.create_from_arxiv_id(arxiv_id)
    paper = Paper.new
    paper.doi = "10.48550/arxiv.#{arxiv_id}"
    paper.save
    paper
  end

  def self.import_arxiv
    arxiv_id_file_name = 'data/arxiv_ids.json'
    arxiv_ids = JSON.parse(File.read(arxiv_id_file_name))
    arxiv_ids.each do |arxiv_id|
      next if arxiv_id.blank?
      next if arxiv_id.start_with?('0000.')
      puts "Importing #{arxiv_id}"
      paper = Paper.create_from_arxiv_id(arxiv_id)
      paper.update_openalex_data
    end
  end

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

  def download_url
    if arxiv?
      return arxiv_pdf_url
    else
      return nil unless openalex_data
      openalex_data['primary_location']['pdf_url']
    end
  end

  def arxiv?
    doi.downcase.start_with?('10.48550/arxiv')
  end

  def arxiv_id
    return nil unless arxiv?
    # 10.48550/arxiv.2103.12345v10
    # remove the 10.48550/arxiv. prefix
    doi.downcase.gsub('10.48550/arxiv.', '')
  end

  def arxiv_url
    "https://arxiv.org/abs/#{arxiv_id}"
  end

  def arxiv_pdf_url
    "https://arxiv.org/pdf/#{arxiv_id}"
  end

  def pdf
    return nil unless download_url  
    @pdf_text ||= fetch_pdf
  end

  def fetch_pdf
    pdf_content = URI.open(download_url)
    pdf = PDF::Reader.new(pdf_content)
  end

  def parse_urls
    return [] unless download_url
    return [] unless pdf
    
    unique_urls = []
    url_regex = /https?:\/\/[\w.-]+(?:\.[\w.-]+)+(?:\/[\w\-\._~:\/?#\[\]@!$&'()*+,;=]*)?/
  
    pdf.pages.each_with_index do |page, index|
      if page.attributes.key?(:Annots)
        Array(page.attributes[:Annots]).each do |annot|
          data = pdf.objects.deref(annot)
          if data[:A] && data[:A][:URI]
            url = data[:A][:URI]
            unique_urls << url unless unique_urls.any? { |existing_url| url.include?(existing_url) || existing_url.include?(url) }
          end
        end
      end

      page.text.scan(url_regex) do |url|
        unique_urls << url unless unique_urls.any? { |existing_url| url.include?(existing_url) || existing_url.include?(url) }
      end
    end
  
    unique_urls.map(&:strip).reject{|url| !url.start_with?('http')}
  rescue => e
    puts "Error parsing URLs for #{doi}: #{e}"
    []
  end

  def update_urls
    self.urls = parse_urls
    self.save
  end
end
