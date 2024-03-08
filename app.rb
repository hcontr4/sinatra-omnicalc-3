require "sinatra"
require "sinatra/reloader"
require "sinatra/cookies"

require "http"
require "json"

get("/") do
  erb(:landing)
end

get("/umbrella") do
  erb(:umbrella)
end

post("/process_umbrella") do

  # Load required keys
  google_api_key = ENV["GMAPS_KEY"]
  pirate_api_key = ENV["PIRATE_WEATHER_KEY"]

  @user_location = params[:user_location]

  gmaps_response = HTTP.get("https://maps.googleapis.com/maps/api/geocode/json?address=#{@user_location}&key=#{google_api_key}")
  parsed_gmaps_data = JSON.parse(gmaps_response)

  @lat = parsed_gmaps_data["results"].first["geometry"]["location"]["lat"]
  @lng = parsed_gmaps_data["results"].first["geometry"]["location"]["lng"]

  # From possibleSolution.rb - start
  pirate_weather_url = "https://api.pirateweather.net/forecast/#{pirate_api_key}/#{@lat},#{@lng}"

  raw_pirate_weather_data = HTTP.get(pirate_weather_url)
  parsed_pirate_weather_data = JSON.parse(raw_pirate_weather_data)

  currently_hash = parsed_pirate_weather_data.fetch("currently")
  @current_temp = currently_hash.fetch("temperature")

  # Some locations around the world do not come with minutely data.
  minutely_hash = parsed_pirate_weather_data.fetch("minutely", false)

  hourly_hash = parsed_pirate_weather_data.fetch("hourly")

  hourly_data_array = hourly_hash.fetch("data")
  @next_hour_summary = hourly_data_array.first["summary"]

  next_twelve_hours = hourly_data_array[1..12]
  
  precip_prob_threshold = 0.10

  any_precipitation = false

  next_twelve_hours.each do |hour_hash|
    precip_prob = hour_hash.fetch("precipProbability")

    if precip_prob > precip_prob_threshold
      any_precipitation = true
    end
  end
  # possibleSolution.rb - end

  @umbrella_needed = any_precipitation ? "You might want to take an umbrella!" : "You probably won't need an umbrella."

  erb(:process_umbrella)
end

get("/message") do
  erb(:message)
end

post("/process_single_message") do
  @message = params[:the_message]

  request_headers_hash = {
    "Authorization" => "Bearer #{ENV["OPENAI_API_KEY"]}",
    "content-type" => "application/json",
  }

  request_body_hash = {
    "model" => "gpt-3.5-turbo",
    "messages" => [
      {
        "role" => "system",
        "content" => "You are a helpful assistant who talks like Shakespeare.",
      },
      {
        "role" => "user",
        "content" => @message,
      },
    ],
  }

  request_body_json = JSON.generate(request_body_hash)

  raw_response = HTTP.headers(request_headers_hash).post(
    "https://api.openai.com/v1/chat/completions",
    :body => request_body_json,
  ).to_s

  parsed_response = JSON.parse(raw_response)
  @reply = parsed_response["choices"].first["message"]["content"]

  erb(:process_single_message)
end

get("/chat") do
  @messages = cookies.key?(:messages) ? JSON.parse(cookies[:messages])[1..] : []
  erb(:chat)
end

post("/add_message_to_chat") do

  @new_message = params[:user_message]
  messages = cookies[:messages].nil? ? "" : JSON.parse(cookies[:messages])

  request_headers_hash = {
    "Authorization" => "Bearer #{ENV["OPENAI_API_KEY"]}",
    "content-type" => "application/json",
  }

  # Create new conversation
  if messages.empty?
    messages = [{
      "role" => "system",
      "content" => "You are a helpful assistant who talks like Shakespeare.",
    },
    {
      "role" => "user",
      "content" => @new_message,
    }]
    # Add to existing conversation
  elsif 
    messages << {
      "role" => "user",
      "content" => @new_message,
    }
  end

  request_body_hash = {
    "model" => "gpt-3.5-turbo",
    "messages" => messages,
  }

  request_body_json = JSON.generate(request_body_hash)

  raw_response = HTTP.headers(request_headers_hash).post(
    "https://api.openai.com/v1/chat/completions",
    :body => request_body_json,
  ).to_s

  parsed_response = JSON.parse(raw_response)
  reply = { 
    "role" => "assistant",
    "content" => parsed_response["choices"].first["message"]["content"]
  }
  messages << reply

  # Add new message and response
  cookies[:messages] = JSON.generate(messages)

  redirect to "/chat"
end

post("/clear_chat") do
  cookies.delete(:messages)
  redirect to "/chat"
end
