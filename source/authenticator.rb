require 'httparty'

class Authenticator
  # Returns a contributor.
  # Return error = 0 cannot authenticate user with Github.
  # Return error = 1 user is not a contributor.
  def signin_with_code(code)
    return { 'error' => true, 'error_code' => 0 } if code.to_s.size == 0

    # Verify the user is authenticated with GitHub.
    access_token = get_access_token(code)
    return { 'error' => true, 'error_code' => 0 } unless access_token
    user = get_user(access_token)
    return { 'error' => true, 'error_code' => 0 } unless user

    # Verify the user is a contributor.
    contributor = nil
    contributor = $database.get_contributor(user['login'].to_s)
    contributor = $database.get_contributor(user['email'].to_s) if contributor.nil? && !user['email'].nil?
    return { 'error' => true, 'error_code' => 1 } unless contributor

    # Update the contributor with the access_token.
    contributor = $database.update_access_token(contributor['username'], access_token)

    {
      'contributor' => contributor
    }
  end

  # Returns a contributor.
  # Return error = 0 cannot authenticate user with Github.
  # Return error = 1 user is not a contributor.
  def signin_with_access_token(access_token)
    return { 'error' => true, 'error_code' => 0 } if access_token.to_s.size == 0

    # Verify the user is authenticated with GitHub.
    user = get_user(access_token)
    return { 'error' => true, 'error_code' => 0 } unless user

    # Verify the user is a contributor.
    contributor = nil
    contributor = $database.get_contributor(user['login'].to_s)
    contributor = $database.get_contributor(user['email'].to_s) if contributor.nil? && !user['email'].nil?
    return { 'error' => true, 'error_code' => 1 } unless contributor

    {
      'contributor' => contributor
    }
  end

  private

  # Returns an access_token from Github or nil if not found.
  # POST response will look like this:
  #   access_token=e4546153abea3890ac63b63d2d85e17272b852d7&scope=&token_type=bearer
  def get_access_token(code)
    response = HTTParty.post("https://github.com/login/oauth/access_token?client_id=#{github_client_id}&client_secret=#{github_client_secret}&code=#{code}")
    raise unless response.code.to_s.start_with?('2')

    access_token = nil
    parts = response.parsed_response.split("&")
    parts.each do |part|
      subpart = part.split('=')
      if subpart[0] == 'access_token'
        return subpart[1]
      end
    end
  end

  # Returns a user hash from GitHub or nil if not found.
  # Each access_token can make 5000 requests per hour to GitHub.
  def get_user(access_token)
    HTTParty.get("https://api.github.com/user",
      headers: {
        'Content-Type' => 'application/json',
        'Authorization' => "token #{access_token}"
      }
    ).parsed_response
  end

  def github_client_id
    return ENV['GH_CLIENT_ID_DEVELOPMENT']  if $environment == 'development'
    return ENV['GH_CLIENT_ID_STAGE']        if $environment == 'stage'
    return ENV['GH_CLIENT_ID_PRODUCTION']   if $environment == 'production'
  end

  def github_client_secret
    return ENV['GH_CLIENT_SECRET_DEVELOPMENT']  if $environment == 'development'
    return ENV['GH_CLIENT_SECRET_STAGE']        if $environment == 'stage'
    return ENV['GH_CLIENT_SECRET_PRODUCTION']   if $environment == 'production'
  end
end
