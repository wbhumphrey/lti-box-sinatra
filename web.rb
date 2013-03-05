require 'sinatra'

get '/' do
  "Invalid Launch Request"
end

post '/' do
  redirect "https://www.box.com/embed_widget/000000000000/files/0/f/0"
end