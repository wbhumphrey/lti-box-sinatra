require 'sinatra'
enable :sessions

get '/' do
  "Invalid Launch Request"
end

get '/return_content' do
  return 'Invalid return URL' unless session.key? :launch_presentation_return_url
  return 'Expected box view URL' unless params.key? :view_url

  require 'URI'
  require 'open_uri'

  redirect_url = URI.parse session[:launch_presentation_return_url]

  url_scheme = request.ssl? ? "https" : "http"
  domain = request.env['SERVER_NAME']
  tool_url = "#{url_scheme}://#{request.env['HTTP_HOST']}/?box_file_key=#{box_params[:view_url][/\/s\/.*$/,1]}"

  title_param = (params.key?(:file_name) ? "&title=#{params[:file_name]}" : "" )

  redirect_url.query = "url=#{URI::encode(tool_url)}#{title_param}"

  session.clear
  session[:canvas_redirect] = redirect_url.to_s
end

post '/' do
  session[:launch_presentation_return_url] = params[:launch_resentation_return_url]

  if params[:box_file_key]
    iframe_src = "https://www.box.com/embed_widget/000415338141/s/#{params[:box_file_key]}?promoted_app_ids=2288"
  else
    iframe_src =  "https://www.box.com/embed_widget/000415338141/files/0/f/0?promoted_app_ids=2288"
  end

  erb :index, :locals => { :iframe_src => iframe_src }
end

get '/canvas_redirect' do
  require 'json'

  content_type :json
  ret_value = (session.key?(:canvas_redirect) ? { :canvas_redirect => session[:canvas_redirect] } :  {})
  session.clear
  ret_value.to_json
end