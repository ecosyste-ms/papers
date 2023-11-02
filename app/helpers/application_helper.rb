module ApplicationHelper
  def meta_title
    [@meta_title, 'Ecosyste.ms: Papers'].compact.join(' | ')
  end

  def meta_description
    @meta_description || 'An open API service providing mapping between scientific papers and software projects that are mentioned in them.'
  end
end
