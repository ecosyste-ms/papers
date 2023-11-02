class PapersController < ApplicationController
  def index
    scope = Paper.all

    if params[:sort].present? || params[:order].present?
      sort = params[:sort] || 'published_at'
      order = params[:order] || 'desc'
      sort_options = sort.split(',').zip(order.split(',')).to_h
      scope = scope.order(sort_options)
    else
      scope = scope.order('mentions_count DESC')
    end

    @pagy, @papers = pagy(scope)
  end

  def show
    @paper = Paper.find_by_doi(params[:id])
    @pagy, @projects = pagy(@paper.projects.order('ecosystem asc'))
  end
end
