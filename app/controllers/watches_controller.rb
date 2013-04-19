class WatchesController < ApplicationController
  # Check Enabled
  before_filter only: [:vendor_projects] { |c| c.check_enabled!('watch_projects') }

  # Load
  before_filter :load_watchable, only: [:post]

  # Authorize
  before_filter only: [:post] { |c| c.authorize! :watch, @watchable }
  before_filter :authenticate_vendor!, only: [:vendor_projects]

  def post
    current_user.send(current_user.watches?(params[:watchable_type], params[:watchable_id]) ? :unwatch! : :watch!,
                      params[:watchable_type], params[:watchable_id])

    respond_to do |format|
      format.html { redirect_to :back }
      format.json {}
    end
  end

  def vendor_projects
    @projects = Project.includes(:watches)
                       .where("watches.user_id = ?", current_vendor.id)
                       .order("projects.updated_at DESC")
                       .paginate(page: params[:page])
  end

  private
  def load_watchable
    @watchable = params[:watchable_type].constantize.find(params[:watchable_id])
    return not_found if !@watchable
  end
end
