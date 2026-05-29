class Api::LiveController < ApplicationController
  def window
    game_id = params[:game_id]
    # First call without startingTime to get latest timestamp, then use it
    url = "https://feed.lolesports.com/livestats/v1/window/#{game_id}"
    url += "?startingTime=#{params[:startingTime]}" if params[:startingTime].present?
    response = HTTParty.get(url, headers: { "Accept" => "application/json" })
    Rails.logger.info "LiveStats #{response.code}: #{response.body.to_s[0..200]}"
    render json: response.parsed_response, status: response.code
  rescue => e
    render json: { error: e.message }, status: 500
  end

  LEAGUE_GROUPS = {
    "top" => %w[lck lpl lta lta-north lcs lec msi worlds],
    "wc"  => %w[lta-south lta-s vcs pcs ljl lco],
    "erl" => %w[al ebl rol hm lfl prm hll lit rl lplol les tcl nlc]
  }.freeze

  def upcoming_games
    url = "https://esports-api.lolesports.com/persisted/gw/getSchedule?hl=en-US"
    url += "&pageToken=#{params[:pageToken]}" if params[:pageToken].present?

    response = HTTParty.get(url, headers: { "x-api-key" => "0TvQnueqKa5mxJntVWt0w4LpLfEkrV1Ta8rQBb9Z" })
    events = response.dig("data", "schedule", "events") || []
    newer_token = response.dig("data", "schedule", "pages", "newer")

    unstarted = events.select { |e|
      e["state"] == "unstarted" &&
      (e.dig("match", "teams") || []).none? { |t| t["name"].to_s.strip.upcase == "TBD" || t["name"].to_s.strip.empty? } &&
      matches_league_filter?(e, params[:filter])
    }

    render json: { events: unstarted, newerToken: newer_token }
  rescue => e
    render json: { error: e.message }, status: 500
  end

  def recent_games
    url = "https://esports-api.lolesports.com/persisted/gw/getSchedule?hl=en-US"
    url += "&pageToken=#{params[:pageToken]}" if params[:pageToken].present?

    response = HTTParty.get(url, headers: { "x-api-key" => "0TvQnueqKa5mxJntVWt0w4LpLfEkrV1Ta8rQBb9Z" })
    events = response.dig("data", "schedule", "events") || []
    older_token = response.dig("data", "schedule", "pages", "older")

    completed = events.select { |e|
      e["state"] == "completed" && matches_league_filter?(e, params[:filter])
    }

    render json: { events: completed, olderToken: older_token }
  rescue => e
    render json: { error: e.message }, status: 500
  end

  private

  def matches_league_filter?(event, filter)
    return true if filter.blank?
    slug = event.dig("league", "slug").to_s.downcase
    if LEAGUE_GROUPS.key?(filter)
      LEAGUE_GROUPS[filter].include?(slug)
    else
      slug == filter.downcase
    end
  end

  def details
    game_id = params[:game_id]
    url = "https://feed.lolesports.com/livestats/v1/details/#{game_id}"
    url += "?startingTime=#{params[:startingTime]}" if params[:startingTime].present?
    response = HTTParty.get(url, headers: { "Accept" => "application/json" })
    Rails.logger.info "LiveStats #{response.code}: #{response.body.to_s[0..200]}"
    render json: response.parsed_response, status: response.code
  rescue => e
    render json: { error: e.message }, status: 500
  end
end
