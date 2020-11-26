class Logs
  def initialize
    @s3 = Aws::S3::Resource.new
  end

  def log(command, contributor)
    object = @s3.bucket(bucket_name).object("logs/#{command}/#{contributor['username']}/#{Time.now.getutc.to_s}")
    object.put(body: contributor.to_json)
  rescue StandardError => e
    puts "Error uploading to S3: #{e.message}"
  end

  private

  def bucket_name
    return 'bitcoin-bootstrap-production' if $environment == 'production'
    'bitcoin-bootstrap-stage'
  end
end
