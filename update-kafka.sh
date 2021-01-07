VERSION=2.7.0
wget http://apache.osuosl.org/kafka/$VERSION/kafka_2.13-$VERSION.tgz
tar -xf kafka_2.13-$VERSION.tgz
rm -rf ./kafka
mv kafka_2.13-$VERSION ./kafka
rm kafka_2.13-$VERSION.tgz