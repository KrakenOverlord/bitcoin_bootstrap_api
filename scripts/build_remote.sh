rm -rf ruby
rm -rf vendor
rm Gemfile.lock
rm -rf temp
rm -rf .bundle

docker run --rm -it -v $PWD:/var/gem_build -w /var/gem_build lambci/lambda:build-ruby2.7 bundle install --without test --path=.

mkdir temp
cp -r ruby temp
cd source
cp -r * ../temp
cd ../temp
zip -r lambda_function.zip *.rb protobufs ruby -x ./ruby/2.5.0/cache/\*
mv lambda_function.zip ..
cd ..

rm -rf ruby
rm -rf vendor
rm Gemfile.lock
rm -rf temp
rm -rf .bundle
