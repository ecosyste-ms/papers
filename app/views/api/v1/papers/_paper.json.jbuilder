json.extract! paper, :id, :doi, :openalex_id, :title, :publication_date, :mentions_count, :last_synced_at, :openalex_data
json.paper_url api_v1_paper_url(paper)
json.mentions_url mentions_api_v1_paper_url(paper)