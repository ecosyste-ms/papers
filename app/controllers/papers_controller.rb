class PapersController < ApplicationController
  def index
    scope = Paper.with_openalex_id

    if params[:sort].present? || params[:order].present?
      sort = params[:sort] || 'mentions_count'
      order = params[:order] || 'desc'
      
      # Whitelist of allowed sort columns to prevent SQL injection
      allowed_sort_columns = %w[doi openalex_id title publication_date mentions_count created_at updated_at last_synced_at]
      allowed_order_directions = %w[asc desc]
      
      sort_columns = sort.split(',').map(&:strip)
      order_directions = order.split(',').map(&:strip)
      
      # Build safe order clauses using Arel.sql
      order_clauses = []
      sort_columns.zip(order_directions).each do |col, dir|
        if allowed_sort_columns.include?(col) && allowed_order_directions.include?(dir&.downcase)
          order_clauses << Arel.sql("#{col} #{dir.upcase}")
        end
      end
      
      if order_clauses.any?
        scope = scope.order(order_clauses)
      else
        scope = scope.order(Arel.sql('mentions_count DESC'))
      end
    else
      scope = scope.order(Arel.sql('mentions_count DESC'))
    end

    @pagy, @papers = pagy(scope)
  end

  def show
    @paper = Paper.find_by_doi!(params[:id])
    @pagy, @projects = pagy(@paper.projects.order('ecosystem asc, name asc'))
  end
end
