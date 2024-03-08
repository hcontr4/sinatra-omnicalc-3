require "sinatra"
require "sinatra/reloader"
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

  if minutely_hash
    @next_hour_summary = minutely_hash.fetch("summary")
  else
    @next_hour_summary = hour_hash["data"].first
  end

  hourly_hash = parsed_pirate_weather_data.fetch("hourly")

  hourly_data_array = hourly_hash.fetch("data")

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
