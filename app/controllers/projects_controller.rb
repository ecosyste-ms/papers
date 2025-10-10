class ProjectsController < ApplicationController
  def index
    scope = Project.all
    scope = scope.search(params[:q]) if params[:q].present?

    if params[:sort].present? || params[:order].present?
      sort = params[:sort].presence || 'mentions_count'

      if params[:order] == 'asc'
        scope = scope.order(Arel.sql(sort).asc.nulls_last)
      else
        scope = scope.order(Arel.sql(sort).desc.nulls_last)
      end
    else
      scope = scope.order('mentions_count DESC nulls last')
    end

    @pagy, @projects = pagy(scope)
  end

  def ecosystem
    scope = Project.where(ecosystem: params[:ecosystem])
    scope = scope.search(params[:q]) if params[:q].present?

    if params[:sort].present? || params[:order].present?
      sort = params[:sort].presence || 'mentions_count'

      if params[:order] == 'asc'
        scope = scope.order(Arel.sql(sort).asc.nulls_last)
      else
        scope = scope.order(Arel.sql(sort).desc.nulls_last)
      end
    else
      scope = scope.order('mentions_count DESC nulls last')
    end

    @pagy, @projects = pagy(scope)
  end

  def show
    @project = Project.where(ecosystem: params[:ecosystem], name: params[:name]).first
    raise ActiveRecord::RecordNotFound unless @project
    @pagy, @papers = pagy(@project.papers.order('mentions_count DESC nulls last'))
  end
end
