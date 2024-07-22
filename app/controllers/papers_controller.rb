class PapersController < ApplicationController
  def index
    scope = Paper.with_openalex_id

    if params[:sort].present? || params[:order].present?
      sort = params[:sort] || 'mentions_count'
      order = params[:order] || 'desc'
      sort_options = sort.split(',').zip(order.split(',')).to_h
      scope = scope.order(sort_options)
    else
      scope = scope.order('mentions_count DESC')
    end

    @pagy, @papers = pagy(scope)
  end

  def show
    @paper = Paper.find_by_doi!(params[:id])
    @pagy, @projects = pagy(@paper.projects.order('ecosystem asc, name asc'))
  end
end
