require 'spec_helper'

RSpec.describe LambdaFunction do
  def topic(bucket)
    {
      'smp-shared-dev'    => ENV['SNS_TOPIC_ARN_TEST'],
      'smp-shared-stage'  => ENV['SNS_TOPIC_ARN_STAGE'],
      'smp-shared-prod'   => ENV['SNS_TOPIC_ARN_PRODUCTION']
    }[bucket]
  end

  let(:bucket) { ['smp-shared-dev', 'smp-shared-stage', 'smp-shared-prod'].sample }
  let(:key) { "ChannelAdvisorFeeds/Order/TO_SMP/#{Faker::Number.number(digits: 10)}.json" }
  let(:event) do
    {
      "Records" => [
        {
          "s3" => {
            "bucket" => {
              "name" => bucket
            },
            "object" => {
              "key" => key
            }
          }
        }
      ]
    }
  end

  let(:item_id) { Faker::Number.number(digits: 5) }

  let(:order) do
    {
      # Order info
      'ID' => Faker::Number.number(10),
      'CreatedDateUtc' => '2020-10-20T00:00:00Z',
      'BuyerEmailAddress' => Faker::Internet.email,

      # Shipping info
      'ShippingFirstName' => Faker::Name.first_name,
      'ShippingLastName' => Faker::Name.last_name,
      'ShippingAddressLine1' => Faker::Address.street_address,
      'ShippingAddressLine2' => Faker::Address.secondary_address,
      'ShippingCity' => Faker::Address.city,
      'ShippingStateOrProvince' => Faker::Address.state_abbr,
      'ShippingPostalCode' => Faker::Address.zip,
      'ShippingCountry' => Faker::Address.country_code,
      'ShippingDaytimePhone' => Faker::PhoneNumber.phone_number,

      # Billing info
      'BillingFirstName' => Faker::Name.first_name,
      'BillingLastName' => Faker::Name.last_name,
      'BillingAddressLine1' => Faker::Address.street_address,
      'BillingAddressLine2' => Faker::Address.secondary_address,
      'BillingCity' => Faker::Address.city,
      'BillingStateOrProvince' => Faker::Address.state_abbr,
      'BillingPostalCode' => Faker::Address.zip,
      'BillingCountry' => Faker::Address.country_code,
      'BillingDaytimePhone' => Faker::PhoneNumber.phone_number,

      # Pricing info
      'TotalShippingPrice' => Faker::Number.decimal(2,2),
      'TotalTaxPrice' => Faker::Number.decimal(2,2),
      'TotalPrice' => Faker::Number.decimal(2,2),

      # Items
      'Items' => [
        {
          'Sku' => item_id,
          'Title' => Faker::Number.number(digits: 5),
          'Quantity' => Faker::Number.number(digits: 2),
          'UPC' => Faker::Number.number(digits: 5),
          'Weight' => Faker::Number.number(digits: 5),
          'UnitPrice' => Faker::Number.decimal(2,2)
        }
      ],

      # Fulfillments
      'Fulfillments' => [
        {
          'ShippingCarrier' => 'FedEx',
          'ShippingClass' => '2 Day',
        }
      ]
    }
  end

  let(:file) { order.to_json }

  it "returns OK if no exceptions are thrown" do
    allow_any_instance_of(OrderReceivedCa).to receive(:publish_event)
    allow_any_instance_of(OrderReceivedCa).to receive(:archive_file)
    allow_any_instance_of(OrderReceivedCa).to receive(:delete_file)

    expect(subject.lambda_handler(event: event)).to eq('OK')
  end

  it "returns OK if a Aws::S3::Errors::NoSuchKey exception is thrown" do
    allow_any_instance_of(OrderReceivedCa).to receive(:publish_event)
    allow_any_instance_of(OrderReceivedCa).to receive(:archive_file).and_raise(Aws::S3::Errors::NoSuchKey.new(nil, nil))

    expect(subject.lambda_handler(event: event)).to eq('OK')
  end

  it "publishes an OrderReceived event" do
    allow_any_instance_of(OrderReceivedCa).to receive(:archive_file)
    allow_any_instance_of(OrderReceivedCa).to receive(:delete_file)

    allow_any_instance_of(OrderReceivedCa).to receive(:get_file).and_return(file)

    sns = double('sns')
    allow_any_instance_of(OrderReceivedCa).to receive(:sns).and_return(sns)
    expect(sns).to receive(:publish).with(
      topic_arn: topic(bucket),
      subject:   'SmpEvents::OrderReceived',
      message:   OrderReceivedMessage.new(file).json
    )

    subject.lambda_handler(event: event)
  end

  it "archives the order file" do
    allow_any_instance_of(OrderReceivedCa).to receive(:publish_event)
    allow_any_instance_of(OrderReceivedCa).to receive(:delete_file)

    s3 = double('s3')
    allow_any_instance_of(OrderReceivedCa).to receive(:s3).and_return(s3)
    expect(s3).to receive(:copy_object).with(
      copy_source: "#{bucket}/#{key}",
      bucket: bucket,
      key: key.sub('TO_SMP', 'TO_SMP_ARCHIVE')
    )

    subject.lambda_handler(event: event)
  end

  it "deletes the order file" do
    allow_any_instance_of(OrderReceivedCa).to receive(:publish_event)
    allow_any_instance_of(OrderReceivedCa).to receive(:archive_file)

    s3 = double('s3')
    allow_any_instance_of(OrderReceivedCa).to receive(:s3).and_return(s3)
    expect(s3).to receive(:delete_object).with(
      bucket: bucket,
      key: key
    )

    subject.lambda_handler(event: event)
  end
end
