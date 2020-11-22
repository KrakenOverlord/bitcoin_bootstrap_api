require 'spec_helper'

RSpec.describe OrderReceivedMessage do
  def cents(str)
    (BigDecimal(str) * 100).to_i
  rescue ArgumentError
    0
  end

  def order_date(time_string_in_utc)
    utc_time = Time.parse(time_string_in_utc).utc
    utc_time.getlocal("-07:00").to_datetime.strftime("%Y-%m-%d %H:%M:%S")
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

  it "converts the JSON order file into an OrderReceived protobuf" do
    protobuf = OrderReceivedMessage.new(file).protobuf

    expect(protobuf.order.order_uid).to eq("#{order['ID']}M")
    expect(protobuf.order.order_date).to eq(order_date(order['CreatedDateUtc']))
    expect(protobuf.order.shipping_method).to eq(:Business2DayAir)
    expect(protobuf.order.payment_method).to eq(:ExternalPayment)

    # Customer info
    expect(protobuf.order.customer.first_name).to eq(order['BillingFirstName'])
    expect(protobuf.order.customer.last_name).to eq(order['BillingLastName'])
    expect(protobuf.order.customer.full_name).to eq("#{order['BillingFirstName']} #{order['BillingLastName']}")
    expect(protobuf.order.customer.customer_number).to eq(order['BuyerEmailAddress'])
    expect(protobuf.order.customer.email).to eq(order['BuyerEmailAddress'])

    # Metadata
    expect(protobuf.order.meta_data.source).to eq('Channel Advisor')
    expect(protobuf.order.meta_data.marketing_source).to eq('Marketplace')
    expect(protobuf.order.meta_data.direct_marketing_source).to eq('Ebay - US')

    # Shipping info
    expect(protobuf.order.shipping_address.name).to eq("#{order['ShippingFirstName'].to_s} #{order['ShippingLastName'].to_s}")
    expect(protobuf.order.shipping_address.street_address).to eq(order['ShippingAddressLine1'])
    expect(protobuf.order.shipping_address.secondary_address).to eq(order['ShippingAddressLine2'])
    expect(protobuf.order.shipping_address.city).to eq(order['ShippingCity'])
    expect(protobuf.order.shipping_address.state).to eq(order['ShippingStateOrProvince'])
    expect(protobuf.order.shipping_address.zip_code).to eq(order['ShippingPostalCode'])
    expect(protobuf.order.shipping_address.country).to eq(order['ShippingCountry'])
    expect(protobuf.order.shipping_address.phone_number).to eq(order['ShippingDaytimePhone'])

    # Billing info
    expect(protobuf.order.billing_address.name).to eq("#{order['BillingFirstName'].to_s} #{order['BillingLastName'].to_s}")
    expect(protobuf.order.billing_address.street_address).to eq(order['BillingAddressLine1'])
    expect(protobuf.order.billing_address.secondary_address).to eq(order['BillingAddressLine2'].to_s)
    expect(protobuf.order.billing_address.city).to eq(order['BillingCity'])
    expect(protobuf.order.billing_address.state).to eq(order['BillingStateOrProvince'])
    expect(protobuf.order.billing_address.zip_code).to eq(order['BillingPostalCode'])
    expect(protobuf.order.billing_address.country).to eq(order['BillingCountry'])
    expect(protobuf.order.billing_address.phone_number).to eq(order['BillingDaytimePhone'])

    # Pricing info
    expect(protobuf.order.price.shipping).to eq(cents(order['TotalShippingPrice'].to_s))
    expect(protobuf.order.price.tax).to eq(cents(order['TotalTaxPrice'].to_s))
    expect(protobuf.order.price.total).to eq(cents(order['TotalPrice'].to_s))
    expect(protobuf.order.price.tax_rate).to eq('0.0')
    expect(protobuf.order.price.currency_code).to eq('USD')
    expect(protobuf.order.price.currency_rate).to eq('100')
    expect(protobuf.order.price.is_tax_exempt).to eq(false)

    # Lines
    expect(protobuf.order.lines.first.item_number).to eq(order['Items'].first['Sku'].to_s)
    expect(protobuf.order.lines.first.title).to eq(order['Items'].first['Title'].to_s)
    expect(protobuf.order.lines.first.qty_ordered).to eq(order['Items'].first['Quantity'])
    expect(protobuf.order.lines.first.lead_time).to eq(:OneBusinessDay)
    expect(protobuf.order.lines.first.upc).to eq(order['Items'].first['UPC'].to_s)
    expect(protobuf.order.lines.first.weight).to eq(order['Items'].first['Weight'].to_s)
    expect(protobuf.order.lines.first.unit_price).to eq(cents(order['Items'].first['UnitPrice'].to_s))
    expect(protobuf.order.lines.first.ext_price).to eq(cents(order['Items'].first['UnitPrice'].to_s) * order['Items'].first['Quantity'])
  end
end
