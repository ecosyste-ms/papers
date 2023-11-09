class Api::V1::PapersController < Api::V1::ApplicationController
  def index
    scope = Paper.all

    if params[:sort].present? || params[:order].present?
      sort = params[:sort] || 'mentions_count'
      order = params[:order] || 'desc'
      sort_options = sort.split(',').zip(order.split(',')).to_h
      scope = scope.order(sort_options)
    end

    @pagy, @papers = pagy(scope)
  end

  def show
    @paper = Paper.find_by_doi!(params[:id])
  end

  def mentions
    @paper = Paper.find_by_doi!(params[:id])
    @pagy, @mentions = pagy(@paper.mentions.includes(:paper))
  end
end