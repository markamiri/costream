class PagesController < ApplicationController
  LEAGUE_GROUPS = {
    "top" => %w[lck lpl lta lta-north lcs lec msi worlds],
    "wc"  => %w[lta-south lta-s vcs pcs ljl lco],
    "erl" => %w[al ebl rol hm lfl prm hll lit rl lplol les tcl nlc]
  }.freeze

  ALL_LEAGUES = {
    "LCK" => "lck", "LPL" => "lpl", "LTA" => "lta", "LEC" => "lec",
    "MSI" => "msi", "Worlds" => "worlds",
    "LTA South" => "lta-south", "VCS" => "vcs", "PCS" => "pcs", "LJL" => "ljl", "LCO" => "lco",
    "AL" => "al", "EBL" => "ebl", "ROL" => "rol", "HM" => "hm", "LFL" => "lfl",
    "PRM" => "prm", "HLL" => "hll", "LIT" => "lit", "RL" => "rl",
    "LPLOL" => "lplol", "LES" => "les", "TCL" => "tcl", "NLC" => "nlc"
  }.freeze

  def home
    @filter = params[:filter]
    @live_games = fetch_live_games
    @upcoming_games = fetch_upcoming_games
    @recent_games = fetch_recent_games
  end

  private

  def fetch_upcoming_games
    response = HTTParty.get(
      "https://esports-api.lolesports.com/persisted/gw/getSchedule?hl=en-US",
      headers: { "x-api-key" => "0TvQnueqKa5mxJntVWt0w4LpLfEkrV1Ta8rQBb9Z" }
    )

    events = response.dig("data", "schedule", "events") || []
    @upcoming_newer_token = response.dig("data", "schedule", "pages", "newer")
    events.select { |e|
      e["state"] == "unstarted" &&
      (e.dig("match", "teams") || []).none? { |t| t["name"].to_s.strip.upcase == "TBD" || t["name"].to_s.strip.empty? } &&
      matches_filter?(e)
    }.first(10)
  rescue => e
    Rails.logger.error "Failed to fetch upcoming games: #{e.message}"
    []
  end

  def fetch_recent_games
    url = "https://esports-api.lolesports.com/persisted/gw/getSchedule?hl=en-US"
    completed = []

    5.times do
      response = HTTParty.get(url, headers: { "x-api-key" => "0TvQnueqKa5mxJntVWt0w4LpLfEkrV1Ta8rQBb9Z" })
      events = response.dig("data", "schedule", "events") || []
      older_token = response.dig("data", "schedule", "pages", "older")

      completed = events.select { |e| e["state"] == "completed" && matches_filter?(e) }

      if completed.any?
        @recent_older_token = older_token
        return completed.last(10)
      end

      break unless older_token.present?
      url = "https://esports-api.lolesports.com/persisted/gw/getSchedule?hl=en-US&pageToken=#{older_token}"
    end

    @recent_older_token = nil
    completed.last(10)
  rescue => e
    Rails.logger.error "Failed to fetch recent games: #{e.message}"
    []
  end

  def fetch_live_games
    response = HTTParty.get(
      "https://esports-api.lolesports.com/persisted/gw/getSchedule?hl=en-US",
      headers: { "x-api-key" => "0TvQnueqKa5mxJntVWt0w4LpLfEkrV1Ta8rQBb9Z" }
    )

    events = response.dig("data", "schedule", "events") || []
    events.select { |e| e["state"] == "inProgress" && matches_filter?(e) }
  rescue => e
    Rails.logger.error "Failed to fetch live games: #{e.message}"
    []
  end

  def matches_filter?(event)
    return true if @filter.blank?
    slug = event.dig("league", "slug").to_s.downcase
    if LEAGUE_GROUPS.key?(@filter)
      LEAGUE_GROUPS[@filter].include?(slug)
    else
      slug == @filter.downcase
    end
  end
end
