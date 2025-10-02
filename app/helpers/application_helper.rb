module ApplicationHelper
  include Pagy::Frontend
  
  def meta_title
    [@meta_title, 'Ecosyste.ms: Papers'].compact.join(' | ')
  end

  def meta_description
    @meta_description || app_description
  end

  def app_name
    "Papers"
  end

  def app_description
    'An open API service providing mapping between scientific papers and software projects that are mentioned in them.'
  end

  def sort_by_semver_range(hash, limit)
    hash.sort_by{|_k,v| -v}
               .first(limit)
               .sort_by{|k,_v|
                 k.gsub(/\~|\>|\<|\^|\=|\*|\s/,'')
                 .gsub('-','.')
                 .split('.').map{|i| i.to_i}
               }.reverse
  end

  def download_period(downloads_period)
    case downloads_period
    when "last-month"
      "last month"
    when "total"
      "total"
    end
  end

  def sanitize_user_url(url)
    return unless url && url.is_a?(String)
    return unless url =~ /\A#{URI::regexp}\z/
    sanitize_url(url, :schemes => ['http', 'https'])
  end

  def science_score_badge(score)
    return unless score.present?

    case score
    when 0..19
      badge_class = "bg-danger"  # Uses ecosyste.ms orange-dark
      badge_text = "Unlikely Science"
    when 20..39
      badge_class = "bg-warning"  # Uses ecosyste.ms orange-light
      badge_text = "Possibly Science"
    when 40..59
      badge_class = "bg-info"  # Uses ecosyste.ms purple-light
      badge_text = "Likely Science"
    else
      badge_class = "bg-success"  # Uses ecosyste.ms green-dark
      badge_text = "Very Likely Science"
    end

    content_tag(:span, "#{badge_text} (#{score})", class: "badge #{badge_class} me-2")
  end

  def bootstrap_icon(symbol, options = {})
    return "" if symbol.nil?
    icon = BootstrapIcons::BootstrapIcon.new(symbol, options)
    content_tag(:svg, icon.path.html_safe, icon.options)
  end
end
