class ProjectsController < ApplicationController
  def index
    scope = Project.all

    if params[:sort].present? || params[:order].present?
      sort = params[:sort] || 'mentions_count'
      order = params[:order] || 'desc'
      sort_options = sort.split(',').zip(order.split(',')).to_h
      scope = scope.order(sort_options)
    else
      scope = scope.order('mentions_count DESC')
    end

    @pagy, @projects = pagy(scope)
  end

  def ecosystem
    scope = Project.where(ecosystem: params[:ecosystem])

    if params[:sort].present? || params[:order].present?
      sort = params[:sort] || 'mentions_count'
      order = params[:order] || 'desc'
      sort_options = sort.split(',').zip(order.split(',')).to_h
      scope = scope.order(sort_options)
    else
      scope = scope.order('mentions_count DESC')
    end

    @pagy, @projects = pagy(scope)
  end

  def show
    @project = Project.where(ecosystem: params[:ecosystem], name: params[:name]).first
    raise ActiveRecord::RecordNotFound unless @project
    @pagy, @papers = pagy(@project.papers.order('mentions_count DESC'))
  end
end
