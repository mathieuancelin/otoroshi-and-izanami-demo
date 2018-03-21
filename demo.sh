#!/bin/sh

LOCATION=`pwd`

export CLAIM_SHAREDKEY="otoroshisharedkey"

press_key_to_continue () {
	echo ""
	read -p "Press any key to continue... " -n1 -s
	echo ""
}

start_otoroshi()  {
  mkdir $LOCATION/oto-run
  cd oto-run
  java \
	  -Dapp.claim.sharedKey=otoroshisharedkey \
	  -Dhttp.port=8081 \
	  -Dapp.adminLogin=demo@admin.io \
	  -Dapp.adminPassword=demoIzaOto \
	  -jar $LOCATION/otoroshi.jar & 
  cd $LOCATION	
}

kill_otoroshi () {
	ps aux  |  grep -i 8081 |  grep -v grep   | awk '{print $2}' | xargs kill 
	rm -rf $LOCATION/oto-run
}

start_izanami () {
	mkdir $LOCATION/iza-run
	cd iza-run
	docker run -p 2181:2181 -p 9092:9092 --env ADVERTISED_HOST=127.0.0.1 --env ADVERTISED_PORT=9092 --env AUTO.CREATE.TOPICS.ENABLE spotify/kafka
	docker rm redis-iznanami 
	docker run --name redis-iznanami -v $(pwd)/redisdata:/data -p 6379:6379 redis
	java -jar -Dizanami.events.store=Kafka -Dizanami.db.default=Redis izanami.jar &
	cd $LOCATION
}

kill_izanami () {
	ps aux  |  grep -i 9000 |  grep -v grep   | awk '{print $2}' | xargs kill 
	docker kill $(docker ps -q)		
	rm -rf $LOCATION/iza-run
}

cleanup () {
	rm -rf $LOCATION/otoroshi
	rm -rf $LOCATION/otoroshi.jar
	rm -rf $LOCATION/izanami
	rm -rf $LOCATION/izanami.jar
	rm -rf $LOCATION/logs
	rm -rf $LOCATION/otoroshicli
	rm -rf $LOCATION/redisdata
	rm -rf $LOCATION/iza-run
}

setup_otoroshi () {
	if [ ! -d "$LOCATION/otoroshi" ]; then
		git clone https://github.com/MAIF/otoroshi.git --depth=1
	fi
	if [ ! -f "$LOCATION/otoroshi.jar" ]; then
		wget -q --show-progress 'https://dl.bintray.com/maif/binaries/otoroshi.jar/snapshot/otoroshi.jar'
	fi
	if [ ! -f "$LOCATION/otoroshicli" ]; then
		wget -q --show-progress 'https://dl.bintray.com/maif/binaries/mac-otoroshicli/1.1.0/otoroshicli'
	fi
	chmod +x $LOCATION/otoroshicli	
	cd otoroshi/clients/demo
	cp -v $LOCATION/otoroshicli ./otoroshicli
	cp -v $LOCATION/otoroshi.jar ./otoroshi.jar
	cp -v $LOCATION/otoroshicli.toml ./otoroshicli.toml
	if [ ! -d "$LOCATION/otoroshi/clients/demo/node_modules" ]; then
		yarn install
	fi
	cd $LOCATION
}

setup_izanami () {
	if [ ! -d "$LOCATION/izanami" ]; then
		git clone https://github.com/MAIF/izanami.git --depth=1
	fi
	if [ ! -f "$LOCATION/izanami.jar" ]; then
		wget --quiet 'https://dl.bintray.com/maif/binaries/izanami.jar/latest/izanami.jar'
	fi
	# TODO : setup whatever else needed here 
	cp $LOCATION/patch $LOCATION/izanami/patch
	cd izanami
	git apply ./patch
	rm -rf ./patch
	cd $LOCATION
}

demo1_scenario () {
	start_otoroshi 
	echo "Wait for otoroshi to start and"
	echo "log into http://otoroshi.foo.bar:8081"
	press_key_to_continue
	$LOCATION/otoroshicli services create \
	  --group default \
	  --id geo-api \
	  --name geo-api \
	  --env prod \
	  --domain foo.bar \
	  --subdomain geo \
	  --root / \
	  --target "https://freegeoip.net" \
	  --public-pattern '/.*' \
	  --no-force-https >> /dev/null
    sleep 1
    echo "Command: curl -H 'Host: geo.foo.bar' http://127.0.0.1:8081/"
	press_key_to_continue
	echo "Command: curl -H 'Host: geo.foo.bar' http://127.0.0.1:8081/json/ | jqn"
	press_key_to_continue
	$LOCATION/otoroshicli services update geo-api --root '/json/' >> /dev/null
	echo "Command: curl -H 'Host: geo.foo.bar' http://127.0.0.1:8081/ | jqn"
	press_key_to_continue
	$LOCATION/otoroshicli services update geo-api --root '/xml/' >> /dev/null
	echo "Command: curl -H 'Host: geo.foo.bar' http://127.0.0.1:8081/"
	press_key_to_continue
	kill_otoroshi
}

demo2_scenario () {
	cd otoroshi/clients/demo
	start_otoroshi 
	echo "Wait for otoroshi to start and"
	echo "log into http://otoroshi.foo.bar:8081"
	press_key_to_continue
	node demo.js server --port 8082 --name "server 1" &
	node demo.js server --port 8083 --name "server 2" &
	node demo.js server --port 8084 --name "server 3" &
	echo "Commands: curl http://127.0.0.1:8082/"
	echo "          curl http://127.0.0.1:8083/"
	echo "          curl http://127.0.0.1:8084/"
	press_key_to_continue
	$LOCATION/./otoroshicli services create --group default \
	  --id hello-api \
	  --name hello-api \
	  --env prod \
	  --domain foo.bar \
	  --subdomain api \
	  --root / \
	  --target "http://127.0.0.1:8082" \
	  --public-pattern '/.*' \
	  --no-force-https \
	  --client-retries 3 >> /dev/null
    echo "Command: cd otoroshi/clients/demo;node demo.js injector --location=127.0.0.1:8081"
	press_key_to_continue
	echo "Command: ./otoroshicli services add-target hello-api --target 'http://127.0.0.1:8083'"
	press_key_to_continue
	echo "Command: ./otoroshicli services add-target hello-api --target 'http://127.0.0.1:8084'"
	press_key_to_continue
	echo "Command: ./otoroshicli services rem-target hello-api --target 'http://127.0.0.1:8083'"
	press_key_to_continue
	echo "Command: ./otoroshicli services rem-target hello-api --target 'http://127.0.0.1:8084'"
	press_key_to_continue
	./otoroshicli services add-target hello-api --target 'http://127.0.0.1:8083'
	./otoroshicli services add-target hello-api --target 'http://127.0.0.1:8084'
	sleep 5	
	ps aux  |  grep -i 8083 |  grep -v grep   | awk '{print $2}' | xargs kill 
	press_key_to_continue
	node demo.js server --port 8083 --name "server 2" &
	echo "/otoroshicli services update hello-api --client-retries 3"
	press_key_to_continue
	ps aux  |  grep -i 8083 |  grep -v grep   | awk '{print $2}' | xargs kill 
	press_key_to_continue
	ps aux  |  grep -i 8084 |  grep -v grep   | awk '{print $2}' | xargs kill
	press_key_to_continue	
	node demo.js server --port 8083 --name "server 2" &
	node demo.js server --port 8084 --name "server 3" &
	press_key_to_continue
	ps aux  |  grep -i 8082 |  grep -v grep   | awk '{print $2}' | xargs kill 
	ps aux  |  grep -i 8083 |  grep -v grep   | awk '{print $2}' | xargs kill 
	ps aux  |  grep -i 8084 |  grep -v grep   | awk '{print $2}' | xargs kill 
	kill_otoroshi
}

demo3_scenario () {
	start_otoroshi 
	echo "Wait for otoroshi to start and"
	echo "log into http://otoroshi.foo.bar:8081"
	press_key_to_continue
	$LOCATION/otoroshicli services create \
	  --group default \
	  --id tvshow-frontend \
	  --name tvshow-frontend \
	  --env prod \
	  --domain mytvshow.demo \
	  --subdomain www \
	  --root / \
	  --target "http://127.0.0.1:8080" \
	  --public-pattern '/.*' \
	  --no-force-https \
	  --client-retries 3 >> /dev/null
    echo "Command: open http://www.mytvshow.demo"
	press_key_to_continue
	$LOCATION/otoroshicli services update tvshow-frontend \
	  --enforce-secure-communication true >> /dev/null
    echo "Now fix the damn filter ;)"
	press_key_to_continue
	$LOCATION/otoroshicli groups create \
	  --id tvshow-api-group \
	  --name tvshow-api-group \
	  --desc tvshow-api-group >> /dev/null
    $LOCATION/otoroshicli apikeys create \
	  --clientId YQBMZSdygC \
	  --clientSecret n14qUPt0FSDV6rgLag0mZsyFEIfxwYou \
	  --group tvshow-api-group \
	  --name tvshow-api-key >> /dev/null
	$LOCATION/otoroshicli services create \
	  --group tvshow-api-group \
	  --id tvshow-api \
	  --name tvshow-api \
	  --env prod \
	  --enforce-secure-communication \
	  --domain mytvshow.demo \
	  --subdomain api \
	  --root /api \
	  --target "http://127.0.0.1:8080" \
	  --no-force-https \
	  --client-retries 3 >> /dev/null
	echo "Command: curl -u YQBMZSdygC:n14qUPt0FSDV6rgLag0mZsyFEIfxwYou -H 'Host: api.mytvshow.demo' http://127.0.0.1:8081 | jqn"
	press_key_to_continue
	kill_otoroshi
}

case "${1}" in
  setup_otoroshi)
    setup_otoroshi
    ;;
  demo1_scenario)
  	demo1_scenario
  	;;
  demo2_scenario)
  	demo2_scenario
  	;;
  demo3_scenario)
  	demo3_scenario
  	;;
  setup_izanami) 
	setup_izanami
	;;
  start_otoroshi) 
	start_otoroshi
	;;
  start_izanami) 
	start_izanami
	;;
  cleanup) 
	cleanup
	;;
  *)
    echo "Usage sh demo.sh (setup_otoroshi|setup_izanami|start_otoroshi|start_izanami|cleanup|demo1_scenario|demo2_scenario|demo3_scenario)"
    ;;
esac

exit ${?}