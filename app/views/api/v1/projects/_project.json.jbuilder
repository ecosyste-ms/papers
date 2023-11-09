json.extract! project, :id, :czi_id, :ecosystem, :name, :package, :mentions_count, :last_synced_at
json.project_url api_v1_project_url(project.ecosystem, project.name)
json.mentions_url api_v1_project_mentions_url(project.ecosystem, project.name)