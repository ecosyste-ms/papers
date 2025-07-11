namespace :science do
  desc "Update science scores for top 100 projects by mentions count"
  task :update_scores => :environment do
    puts "Updating science scores for top 100 projects..."
    Project.update_science_scores_for_top_mentioned(100)
    puts "Done!"
  end

  desc "Update science scores for all projects"
  task :update_all_scores => :environment do
    puts "Updating science scores for all projects..."
    Project.update_all_science_scores
    puts "Done!"
  end

  desc "Analyze science scores for top 100 projects by mentions count"
  task :analyze_scores => :environment do
    puts "Top 100 Projects by Mentions Count - Science Score Analysis"
    puts "=" * 80
    
    top_projects = Project.where.not(mentions_count: nil)
                         .order(mentions_count: :desc)
                         .limit(100)
    
    # Update scores for analysis if not already cached
    top_projects.each do |project|
      project.update_science_score! unless project.read_attribute(:science_score)
    end
    
    puts sprintf("%-4s %-20s %-15s %-8s %-8s %-s", 
                 "Rank", "Name", "Ecosystem", "Mentions", "Score", "Description")
    puts "-" * 80
    
    top_projects.each_with_index do |project, index|
      score = project.science_score
      description = project.description&.truncate(40) || "No description"
      
      puts sprintf("%-4d %-20s %-15s %-8d %-8d %-s",
                   index + 1,
                   project.name.truncate(20),
                   project.ecosystem,
                   project.mentions_count,
                   score,
                   description)
    end
    
    puts "\n" + "=" * 80
    puts "Science Score Distribution:"
    
    # Score distribution analysis
    scores = top_projects.map(&:science_score)
    high_scores = scores.count { |s| s >= 50 }
    medium_scores = scores.count { |s| s >= 20 && s < 50 }
    low_scores = scores.count { |s| s < 20 }
    
    puts "High scores (50+):    #{high_scores} packages (#{(high_scores * 100.0 / scores.size).round(1)}%)"
    puts "Medium scores (20-49): #{medium_scores} packages (#{(medium_scores * 100.0 / scores.size).round(1)}%)"
    puts "Low scores (<20):     #{low_scores} packages (#{(low_scores * 100.0 / scores.size).round(1)}%)"
    
    puts "\nAverage science score: #{(scores.sum.to_f / scores.size).round(2)}"
    puts "Median science score:  #{scores.sort[scores.size / 2]}"
    
    # Show some interesting patterns for manual review
    puts "\n" + "=" * 80
    puts "Packages to Review:"
    
    # Zero science score - likely correctly identified non-science
    zero_scores = top_projects.select { |p| p.science_score == 0 }
    if zero_scores.any?
      puts "\nZero science score (likely non-science, correctly identified):"
      zero_scores.first(10).each do |project|
        puts "  #{project.name} (#{project.ecosystem}): #{project.mentions_count} mentions"
        puts "    Description: #{project.description&.truncate(60)}"
      end
    end
    
    # Very high science scores - should be obviously scientific
    very_high_scores = top_projects.select { |p| p.science_score >= 70 }
    if very_high_scores.any?
      puts "\nVery high science scores (should be obviously scientific):"
      very_high_scores.each do |project|
        puts "  #{project.name} (#{project.ecosystem}): score #{project.science_score}"
        puts "    Description: #{project.description&.truncate(60)}"
      end
    end
    
    # Base score only - might need investigation
    base_score_only = top_projects.select { |p| 
      (p.ecosystem == 'bioconductor' && p.science_score == 30) ||
      (p.ecosystem == 'cran' && p.science_score == 10) ||
      (p.ecosystem == 'pypi' && p.science_score == 5)
    }
    if base_score_only.any?
      puts "\nBase ecosystem score only (might be missing science indicators):"
      base_score_only.first(10).each do |project|
        puts "  #{project.name} (#{project.ecosystem}): score #{project.science_score}"
        puts "    Description: #{project.description&.truncate(60)}"
      end
    end
  end
end