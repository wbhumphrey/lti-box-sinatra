require 'sinatra'

get '/' do
  "Invalid Launch Request"
end

post '/' do
  params.to_yaml
end

post '/' do
  redirect "https://www.box.com/embed_widget/000415338141/files/0/f/0?promoted_app_ids=2288"
end