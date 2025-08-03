class ApplicationController < ActionController::Base
  include Pagy::Backend

  before_action :set_cache_headers

  def default_url_options(options = {})
    Rails.env.production? ? { :protocol => "https" }.merge(options) : options
  end

  private

  def set_cache_headers
    return unless Rails.env.production?
    
    expires_in 2.weeks, public: true
    response.headers['Cache-Control'] = 'public, max-age=1209600, s-maxage=1209600'
    response.headers['Vary'] = 'Accept-Encoding'
  end
end
