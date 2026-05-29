class MatchesController < ApplicationController
  def show
    @event_id = params[:event_id]

    # Fetch event details
    response = HTTParty.get(
      "https://esports-api.lolesports.com/persisted/gw/getEventDetails?hl=en-US&id=#{@event_id}",
      headers: { "x-api-key" => "0TvQnueqKa5mxJntVWt0w4LpLfEkrV1Ta8rQBb9Z" }
    )

    @event = response.dig("data", "event")
    @match = @event&.dig("match")
    @teams = @match&.dig("teams") || []
    @games = @match&.dig("games") || []

    # Default to the active (inProgress/unstarted) game, same as Aureom
    if params[:game]
      @default_game_index = params[:game].to_i
    else
      active = @games.index { |g| g["state"] == "inProgress" || g["state"] == "unstarted" }
      if active
        @default_game_index = active
      else
        # All done — default to last completed game
        last = @games.rindex { |g| g["state"] == "completed" }
        @default_game_index = last || 0
      end
    end
  rescue => e
    Rails.logger.error "Failed to fetch match: #{e.message}"
    @event = nil
    @teams = []
    @games = []
  end
end
