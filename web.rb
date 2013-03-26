require 'sinatra'
require 'ims/lti'
require 'oauth/request_proxy/rack_request'

enable :sessions
set :session_secret, ENV['SESSION_SECRET'] ||= 'super secret'

$oauth_creds = {"key" => "secret"}

def register_error(message)
  @error_message = message
end

def show_error(message = nil)
  @message = message || @error_message || "An unexpected error occurred"
  erb :error
end

def authorize!
  key = params['oauth_consumer_key']
  @tp = IMS::LTI::ToolProvider.new(key, $oauth_creds[key], params)

  if !@tp.valid_request?(request)
    register_error "The OAuth signature was invalid"
    return false
  end

  if Time.now.utc.to_i - @tp.request_oauth_timestamp.to_i > 60*60
    register_error "Your request is too old."
    return false
  end

  #if was_nonce_used_in_last_x_minutes?(@tp.request_oauth_nonce, 60)
  #  register_error "Why are you reusing the nonce?"
  #  return false
  #end

  @tp.extend IMS::LTI::Extensions::Content::ToolProvider

  # save the launch parameters for use in later request
  session[:launch_params] = @tp.to_params

  return @tp
end

def host
  url_scheme = request.ssl? ? "https" : "http"
  "#{url_scheme}://#{request.host_with_port}"
end

def box_url(opts = {})
  box_launch_id = 415338140
  box_launch_id += opts[:promoted_app_id].to_i if opts[:promoted_app_id]
  box_launch_id = "%012d" % box_launch_id

  if opts[:box_file_key]
    box_target = "s/#{opts[:box_file_key]}"
  else
    box_target = "files/0/f/0"
  end

  box_url = "https://www.box.com/embed_widget/#{box_launch_id}/#{box_target}"
  box_url = "#{box_url}?promoted_app_ids=#{opts[:promoted_app_id]}" if opts[:promoted_app_id]

  return box_url
end

def box_file_key(view_url)
  view_url[/\/s\/(.*$)/,1]
end

get '/' do
  "Invalid Launch Request"
end

get '/return_content' do
  return 'Invalid launch params' unless session.key? :launch_params
  return 'Invalid return URL' unless session[:launch_params].key? 'launch_presentation_return_url'
  return 'Expected box view URL' unless params.key? 'view_url'

  require 'uri'
  require 'open-uri'
  require 'cgi'


  @tp = IMS::LTI::ToolProvider.new(nil, nil, session[:launch_params])
  @tp.extend IMS::LTI::Extensions::Content::ToolProvider

  file_name = CGI::unescape(params['file_name'])

  if params['file_name'] && @tp.accepts_file?(file_name)
    redirect_url = @tp.file_content_return_url(params['download_url'], file_name)
  elsif @tp.accepts_lti_launch_url?
    url_scheme = request.ssl? ? "https" : "http"
    domain = request.env['SERVER_NAME']
    tool_url = "#{url_scheme}://#{request.env['HTTP_HOST']}/?box_file_key=#{box_file_key(params['view_url'])}"
    redirect_url = @tp.lti_launch_content_return_url(tool_url, file_name)
  elsif @tp.accepts_iframe? && false
    redirect_url = @tp.iframe_content_return_url(box_url(:box_file_key => box_file_key(params['view_url'])), 700, 500)
  elsif @tp.accepts_url?
    redirect_url = @tp.url_content_return_url(params['view_url'], file_name, file_name)
  end

  session.clear
  session[:canvas_redirect] = redirect_url

  redirect "#{params['redirect_to_box_url']}&status=success&message=Almost%20there!%20Your%20file%20will%20be%20in%20canvas%20shortly."
end

post '/' do
  session.clear
  show_error unless authorize!

  box_params = {}
  box_params[:box_file_key] = params[:box_file_key] if params[:box_file_key]
  box_params[:promoted_app_id] = ENV["BOX_APPS"] if @tp.accepts_content?

  erb :index, :locals => { :iframe_src => box_url(box_params) }
end

get '/canvas_redirect' do
  require 'json'

  content_type :json
  ret_value = (session.key?(:canvas_redirect) ? { :canvas_redirect => session[:canvas_redirect] } :  {})
  session.clear unless ret_value.empty?
  ret_value.to_json
end

get '/tool_config.xml' do
  url ="#{host}/"
  tc = IMS::LTI::ToolConfig.new(:title => "My Box", :launch_url => url)

  tc.extend IMS::LTI::Extensions::Canvas::ToolConfig
  tc.canvas_privacy_public!
  tc.canvas_domain! request.host_with_port
  tc.canvas_text! "My Box"
  tc.canvas_icon_url! "#{host}/box.png"
  tc.canvas_selector_dimensions! 800, 800
  params = {:url => host + "/content"}
  tc.canvas_homework_submission! params
  tc.canvas_editor_button! params
  tc.canvas_resource_selection! params

  headers 'Content-Type' => 'text/xml'
  tc.to_xml(:indent => 2)
end