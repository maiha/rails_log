module RailsLogHelper
  ######################################################################
  ### Edit Fields

  def edit_grouped(column_name)
    counts = RailsLog.count(:all, :group=>column_name)
    counts.map do |key, count|
      label = "%s(%s)" % [key, count]
      func  = update_value(column_name, key)
      link_to_function label, func
    end.join('&nbsp;&nbsp;')
  end

  def edit_status
    "%s %s" % [
      text_field_tag(:status, '', :size=>10),
      edit_grouped(:status),
    ]
  end

  def edit_scheme
    "%s %s" % [
      text_field_tag(:scheme, '', :size=>10),
      edit_grouped(:scheme),
    ]
  end

  def edit_address
    text_field_tag(:address, '', :size=>20)
  end

  def edit_session_id
    text_field_tag(:session_id, '', :size=>60)
  end

  def edit_runtime
    avg = ("%.2f" % RailsLog.average(:runtime).to_f).to_f
    off = RailsLog.count(:conditions=>"runtime IS NOT NULL") / 10
    p10 = RailsLog.find(:first, :select=>"runtime",
                        :offset=>off.to_i, :order=>"runtime DESC",
                        :conditions=>"runtime IS NOT NULL").runtime rescue nil
    p10 = ("%.2f" % p10.to_f).to_f if p10
    avg_link = link_to_function("avg(#{avg})", update_value(:runtime, avg)) if avg > 0
    p10_link = link_to_function("top10%(#{p10})", update_value(:runtime, p10)) if p10

    "&gt; %s %s %s" % [
      text_field_tag(:runtime, '', :size=>20),
      avg_link, p10_link,
    ]
  end

  def clear_form(key)
    link_to_function "clear", update_value(key, '')
  end

  def update_value(column_name, value)
    "$('%s').value = '%s'" % [column_name, escape_javascript(value.to_s)]
  end


  ######################################################################
  ### Show Fields

  def show_time
    time  = @rails_log.time.strftime("%Y-%m-%d %H:%M:%S")
#     label = @rails_log.time.strftime("%H:%M:%S")
#     content_tag :span, label, :title=>time
  rescue
    '???'
  end

  def show_scheme
    link_to_search_option :scheme
  rescue
    '???'
  end

  def show_status
    link_to_search_option :status
  rescue
    '???'
  end

  def show_address
    link_to_search_option :address
  rescue
    '???'
  end

  def link_to_search_option(key, value = nil, label = nil, options = {})
    value ||= @rails_log.__send__(key)
    label ||= value.to_s
    if value.blank?
      '-'
    else
      function = "$('list').hide(); $('summary').show(); $('%s').value = '%s'" % [key, escape_javascript(value.to_s)]
      link_to_function h(label), function, options
    end
  end

  def show_controller
    @rails_log.controller
  rescue
    '???'
  end

  def show_action
    @rails_log.action
  rescue
    '???'
  end

  def show_page
    "%s#%s" % [show_controller, show_action]
  end

  def show_session_id
    label = truncate @rails_log.session_id, 10
    link_to_search_option :session_id, @rails_log.session_id, label
  rescue
    '???'
  end

  def show_parameters
    truncated @rails_log.parameters, 40
  rescue
    '???'
    @rails_log.parameters
  end

  def show_runtime
    runtime = @rails_log.runtime
    if runtime.to_f > 0
      percent = rails_log_runtime_percent(runtime.to_f)
      html = "%s %.3f" % [
        image_tag("rails_log/blue.png",  :width=>percent, :height=>11), runtime]
      return content_tag(:div, html, :class=>"nowrap")
    else
      '-'
    end
  rescue
    '???'
  end

  def show_benchmark
    rd = @rails_log.rd_percent.to_i
    db = @rails_log.db_percent.to_i
    lg = 100 - rd - db

    html = ''
    html << image_tag("rails_log/red.png",    :width=>db, :height=>11) if db > 0
    html << image_tag("rails_log/yellow.png", :width=>rd, :height=>11) if rd > 0
    html << image_tag("rails_log/green.png",  :width=>lg, :height=>11)

    return content_tag(:div, html, :class=>"nowrap")
  rescue
    '???'
  end


  ######################################################################
  ### Summary

  def summary_count
    RailsLog.count
  end

  def summary_time
    @time_min = RailsLog.minimum(:time)
    @time_max = RailsLog.maximum(:time)

    "%s - %s" % [
      (@time_min.strftime("%Y-%m-%d %H:%M:%S") rescue ''),
      (@time_max.strftime("%Y-%m-%d %H:%M:%S") rescue ''),
    ]
  end


  ######################################################################
  ### Misc

  def label_benchmark
  end

  def rails_log_tr_id
    "rails_log_%d" % @rails_log.id
  end

  def rails_log_tr_class
    [
      "#{@rails_log.scheme.to_s.downcase}",
      "status#{@rails_log.status.to_i}",
    ].join(' ')
  end

  def truncated(string, size)
    label = truncate string, size
    content_tag :span, label, :title=>string
  end

  def rails_log_runtime_percent(runtime, scale = 100)
    @runtime_max ||= @rails_logs.map{|i| i.runtime.to_f}.max.to_f
    if runtime > 0 and @runtime_max > 0
      if runtime > @runtime_max
        scale
      else
        1.0 * scale * runtime / @runtime_max
      end
    else
      0
    end
  end

  def rails_log_url
    url_for :controller=>@rails_log.controller, :action=>@rails_log.action
  rescue
    '???'
  end

  def list_pagination_links
    "<TABLE class=pagination_links><TR><TD align=left>%s</TD><TD align=center>%s</TD><TD align=right>%s</TD></TR></TABLE>" % [
      (link_to "Prev", { :page => @pages.current.previous } if @pages.current.previous),
      (pagination_links @pages, :window_size=>10 unless @pages.blank?),
      (link_to "Next", { :page => @pages.current.next } if @pages.current.next),
    ]
  end


  ######################################################################
  ### Links
  def link_to_log
    link_to_remote "log", :url=>{:action=>"show", :id=>@rails_log}
  end


  def ext_top
    "/ext"
  end

  def ext_include
    array = []
    array << stylesheet_link_tag("#{ext_top}/resources/css/ext-all")
    array << javascript_include_tag("#{ext_top}/yui-utilities")
    array << javascript_include_tag("#{ext_top}/ext-yui-adapter")

    if RAILS_ENV == 'development'
      array << javascript_include_tag("#{ext_top}/ext-all-debug")
    else
      array << javascript_include_tag("#{ext_top}/ext-all")
    end

    array.join("\n")
  end

  ######################################################################
  ### Ajax

#   def slider(
#   <div id="track1" style="width:200px;background-color:#aaa;height:5px;">
#     <div id="handle1" style="width:5px;height:10px;background-color:#f00;cursor:move;"> </div>
#   </div>
#
#
#   new Control.Slider('handle1','track1',{
#                        onSlide:function(v){$('debug1').innerHTML='slide: '+v},
#                      onChange:function(v){$('debug1').innerHTML='changed! '+v}});
#

end
