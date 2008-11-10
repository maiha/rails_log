class RailsLogController < ApplicationController
private
  def paginate_options(options = {})
    fields = RailsLog.column_names - ["log"]
    {
      :select   => fields.join(', '),
      :per_page => 20,
      :order    => "time",
    }.merge(options)
  end

public
  def index
    list
  end

  def summary
    # >> RailsLog.count(:all, :group=>:status)
    # => [[nil, 50], [200, 4438], [302, 104]]
  end

  def list
    @pages, @rails_logs = paginate RailsLog, paginate_options
  end

  def search
    conds = {}
    [:status, :scheme, :address, :session_id].each do |key|
      conds[key] = params[key].to_s unless params[key].blank?
    end
    unless params[:runtime].blank?
      conds[:runtime] = (params[:runtime].to_f .. 1024)
    end

    options = {}
    options = {:conditions=>conds} unless conds.blank?
    @pages, @rails_logs = paginate RailsLog, paginate_options(options)
    render :update do |page|
      page[:summary].hide unless @rails_logs.blank?
      page[:list].replace :partial=>"list"
      page[:list].show
    end
  end

  def show
    @rails_log = RailsLog.find params[:id]

    if request.xhr?
      render :update do |page|
        page[:list].hide
        page[:show].replace :partial=>"show"
      end
    else
      render :inline=>"<%= content_tag :pre, @rails_log.log %>"
    end
  end

  ######################################################################
  ### Experimental
  ######################################################################

  ### Ext

  include RailsLogHelper
  delegate :content_tag, :image_tag, :to=>"@template"

  def ext_item(log)
    @rails_log = log
    log[:time] = log[:time].to_i if log[:time]
    log[:page] = "%s#%s" % [log[:controller], log[:action]]
    log[:benchmark] = show_benchmark
    log.attributes
  end

  def ext_sorts
    case params[:sort].to_s.strip
    when ''     then []
    when "page" then ["controller", "action"]
    else [params[:sort].to_s]
    end
  end

  def ext
    return unless request.post?

    klass  = RailsLog
    fields = klass.column_names - ["log"]

    options = {
      :offset => [params[:start].to_i-1, 0].max,
      :limit  => params[:limit].to_i,
      :order  => ext_sorts.blank? ? nil : ext_sorts.map{|i| "%s %s" % [i, params[:dir]]}.join(', '),
      :select => fields.join(', '),
    }

    json = {
      "count" => klass.count.to_s,
      "items" => klass.find(:all, options).map{|item| ext_item(item)},
    }.to_json
    render :text=>json
  end
end

