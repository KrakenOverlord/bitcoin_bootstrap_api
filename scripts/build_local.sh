rm -rf ruby
rm -rf vendor
rm Gemfile.lock
bundle install --with test
rm -rf .bundle
