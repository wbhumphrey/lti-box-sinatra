require 'sinatra'
enable :sessions

get '/' do
  "Invalid Launch Request"
end

get '/return_content' do
  return 'Invalid return URL' unless session.key? :launch_presentation_return_url
  return 'Expected box view URL' unless params.key? 'view_url'

  require 'URI'
  require 'open-uri'

  redirect_url = URI.parse session[:launch_presentation_return_url]

  url_scheme = request.ssl? ? "https" : "http"
  domain = request.env['SERVER_NAME']
  tool_url = "#{url_scheme}://#{request.env['HTTP_HOST']}/?box_file_key=#{params['view_url'][/\/s\/(.*$)/,1]}"

  text_param = (params.key?('file_name') ? "&text=#{params['file_name']}" : "")

  redirect_url.query = "embed_type=basic_lti&url=#{CGI::escape(tool_url)}#{text_param}"

  session.clear
  session[:canvas_redirect] = redirect_url.to_s

  redirect "#{params['redirect_to_box_url']}&status=success&message=Almost%20there!%20Your%20file%20will%20be%20in%20canvas%20shortly."
end

post '/' do
  session.clear
  session[:launch_presentation_return_url] = params[:launch_presentation_return_url]

  if params[:box_file_key]
    iframe_src = "https://www.box.com/embed_widget/000415338140/s/#{params[:box_file_key]}"
  elsif session[:launch_presentation_return_url]
    iframe_src =  "https://www.box.com/embed_widget/000415338141/files/0/f/0?promoted_app_ids=2288"
  else
    iframe_src =  "https://www.box.com/embed_widget/000415338140/files/0/f/0"
  end

  erb :index, :locals => { :iframe_src => iframe_src }
end

get '/canvas_redirect' do
  require 'json'

  content_type :json
  ret_value = (session.key?(:canvas_redirect) ? { :canvas_redirect => session[:canvas_redirect] } :  {})
  session.clear unless ret_value.empty?
  ret_value.to_json
end