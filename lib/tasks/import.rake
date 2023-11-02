require 'csv'

namespace :import do
  task czi: :environment do
    # load bioconductor file

    

    # load pypi file

    # load czi file

    # for each doi
      # find or create paper
        # for each mention
          # find or create package
          # create mention
  end

  task cran: :environment do
    projects = []
    file = File.open("data/cran_df.csv", "r")
    csv = CSV.new(file, :headers => true, :header_converters => :symbol, :converters => :all)
    csv.each do |row|
      projects << row.to_hash
    end

    dois = Set.new
    mentions = 0

    # load czi file
    czi_file = File.open("data/comm_disambiguated_dois_count.json", "r")
    czi = JSON.parse(czi_file.read)

    projects.each do |package|
      puts package[:mapped_to]
      project = Project.find_or_create_by(name: package[:mapped_to], ecosystem: "cran")
      project.update(czi_id: package[:id]) if project.czi_id.nil?

      czi[package[:id]].each do |doi|
        puts "  #{doi}"
        dois << doi
        paper = Paper.find_or_create_by(doi: doi)
        Mention.create(paper: paper, project: project)
        mentions += 1
      end
    end

    puts "#{projects.count} projects"
    puts "#{dois.count} dois"
    puts "#{mentions} mentions"
  end

  task bioconductor: :environment do
    projects = []
    file = File.open("data/bioconductor_df.csv", "r")
    csv = CSV.new(file, :headers => true, :header_converters => :symbol, :converters => :all)
    csv.each do |row|
      projects << row.to_hash
    end

    dois = Set.new
    mentions = 0

    # load czi file
    czi_file = File.open("data/comm_disambiguated_dois_count.json", "r")
    czi = JSON.parse(czi_file.read)

    projects.each do |package|
      puts package[:mapped_to]
      project = Project.find_or_create_by(name: package[:mapped_to], ecosystem: "bioconductor")
      project.update(czi_id: package[:id]) if project.czi_id.nil?

      czi[package[:id]].each do |doi|
        puts "  #{doi}"
        dois << doi
        paper = Paper.find_or_create_by(doi: doi)
        Mention.create(paper: paper, project: project)
        mentions += 1
      end
    end

    puts "#{projects.count} projects"
    puts "#{dois.count} dois"
    puts "#{mentions} mentions"
  end

  task pypi: :environment do
    projects = []
    file = File.open("data/pypi_df.csv", "r")
    csv = CSV.new(file, :headers => true, :header_converters => :symbol, :converters => :all)
    csv.each do |row|
      projects << row.to_hash
    end

    dois = Set.new
    mentions = 0

    # load czi file
    czi_file = File.open("data/comm_disambiguated_dois_count.json", "r")
    czi = JSON.parse(czi_file.read)

    projects.each do |package|
      puts package[:mapped_to]
      project = Project.find_or_create_by(name: package[:mapped_to], ecosystem: "pypi")
      project.update(czi_id: package[:id]) if project.czi_id.nil?

      czi[package[:id]].each do |doi|
        puts "  #{doi}"
        dois << doi
        paper = Paper.find_or_create_by(doi: doi)
        Mention.create(paper: paper, project: project)
        mentions += 1
      end
    end

    puts "#{projects.count} projects"
    puts "#{dois.count} dois"
    puts "#{mentions} mentions"
  end
end