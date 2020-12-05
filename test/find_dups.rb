require 'json'
require 'awesome_print'
require 'byebug'

class FindDups
  def execute
    contributors = JSON.parse(File.read('test/contributors.json'))

    logins = {}
    emails = {}
    contributors.each do |contributor|
      login = contributor['login']
      email = contributor['email']

      logins[login] = logins[login].to_i + 1  if contributor['type'] == 'User'

      if contributor['type'] == 'Anonymous'
        if emails[email].nil?
          emails[email] = contributor
        else
          ap emails[email]
          ap contributor
        end
      end
    end

    ap "=============================================================="

    ap "contributors in file = #{contributors.count}"
    ap "logins = #{logins.count}"
    ap "emails = #{emails.count}"
  end
end

FindDups.new.execute
