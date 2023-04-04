datanode = 1
workernode = 1

prepare:
	cp ./docker/template.docker-compose.yml ./docker/docker-compose.yml 

	number=1 ; while [[ $$number -le $(datanode) ]] ; do \
		sed -e 's/{{COUNT}}/'$$number'/g' ./docker/template.datanode.yml > ./docker/temp ; \
		yq -i '.services.datanode'$$number'=load("./docker/temp")' ./docker/docker-compose.yml ; \
		yq -i '.volumes.hadoop_datanode'$$number'="REMOVELATER"' ./docker/docker-compose.yml ; \
		sed -i .bak 's/REMOVELATER//g' ./docker/docker-compose.yml ; \
		printf %s "datanode"$$number":9864 " >> ./docker/tamp ; \
		((number = number + 1)) ; \
	done
	rm -rf ./docker/temp || true

	number=1 ; while [[ $$number -le $(workernode) ]] ; do \
		sed -e 's/{{COUNT}}/'$$number'/g' -e 's/{{PORT}}/'$$((7000+number))'/g' ./docker/template.workernode.yml > ./docker/temp ; \
		yq -i '.services.workernode'$$number'=load("./docker/temp")' ./docker/docker-compose.yml ; \
		((number = number + 1)) ; \
	done
	rm -rf ./docker/temp || true

	sed -i .bak "s/{{PRECONDATANODE}}/$$(cat ./docker/tamp)/g" ./docker/docker-compose.yml
	rm -rf ./docker/tamp || true
	rm -rf ./docker/*.bak || true

up:
	docker compose -f docker/docker-compose.yml up -d

build:
	docker exec namenode mkdir -p /data/app/.generated
	docker exec namenode /bin/bash -c "HADOOP_CLASSPATH=\$${JAVA_HOME}lib/tools.jar hadoop com.sun.tools.javac.Main -d /data/app/.generated /data/app/WordCount.java"
	docker exec namenode /bin/bash -c "cd /data/app/.generated && jar cf ../wc.jar WordCount*.class"

run:
	docker exec namenode hdfs dfs -mkdir -p /data/
	docker exec namenode hdfs dfs -put -f /data/input/. /data/
	docker exec namenode hdfs dfs -rm -r -f /data/output/
	docker exec namenode hadoop jar /data/app/wc.jar WordCount /data/input/ /data/output/

down:
	docker compose -f docker/docker-compose.yml down

clean:
	docker-compose -f docker/docker-compose.yml down --volumes || true

cleanup:
	docker-compose -f docker/docker-compose.yml down --volumes || true
	rm -rf docker/docker-compose.yml || true
	rm -rf .generated