MYSQL_IMAGE = mysql-schoolbox
COOVA_IMAGE = coovachilli-schoolbox
FREERADIUS_IMAGE = freeradius-schoolbox
HOSTAPD_IMAGE = hostapd-schoolbox

# common
IMGTAG = latest
BRIDGE_NETWORK = bridge
HOST_NETWORK = host
WAIT_LIMIT := $(shell seq 1 100)

# mysql-schoolbox
PORT = 3306
MYSQL_ROOT_PASSWORD = password

# freeradius-schoolbox
PORT1 = 1812
PORT2 = 1813
MYSQL_SERVER := $(shell docker inspect --format '{{ .NetworkSettings.IPAddress }}' mysql-schoolbox_run)

# hostapd-schoolbox
WLAN_INT = wlp2s0
CHANNEL = 10


start: mysql hostapd freeradius coovachilli
killall: stopall deleteall

mysql:
	@echo "Installing MySQL"
	@docker run -t -d\
    --name $(MYSQL_IMAGE)_run \
	--net $(BRIDGE_NETWORK) \
	-e MYSQL_ROOT_PASSWORD=$(MYSQL_ROOT_PASSWORD) \
    -p $(PORT):$(PORT) \
	schoolboxsih/$(MYSQL_IMAGE):$(IMGTAG)
	@echo "Waiting 100 seconds for MySQL to finish initilizing"
	@sleep 100s

freeradius:
	@echo "Installing Freeradius"
	@docker run -t -d\
    --name $(FREERADIUS_IMAGE)_run \
	--net $(BRIDGE_NETWORK) \
    -p $(PORT1)-$(PORT2):$(PORT1)-$(PORT2)/udp \
    -e MYSQL_SERVER=$(MYSQL_SERVER) \
	schoolboxsih/$(FREERADIUS_IMAGE):$(IMGTAG)

hostapd:
	@echo "Installing Hostapd"
	@sudo docker run -t -d\
    --name $(HOSTAPD_IMAGE)_run \
	-e INTERFACE=$(WLAN_INT) \
	-e CHANNEL=$(CHANNEL) \
	--privileged \
	--net $(HOST_NETWORK) \
	schoolboxsih/$(HOSTAPD_IMAGE):$(IMGTAG)

coovachilli:
	@echo "Installing Coovachilli"
	@sudo docker run -t -d\
    --name $(COOVA_IMAGE)_run \
	--net $(HOST_NETWORK) \
	--pid $(HOST_NETWORK) \
	--ipc $(HOST_NETWORK) \
	--privileged \
	schoolboxsih/$(COOVA_IMAGE):$(IMGTAG)
	@sudo iptables -I POSTROUTING -t nat -o $(WLAN_INT) -j MASQUERADE

phpmyadmin:
	@echo "Installing phpMyAdmin: 9093"
	@docker run --name phpmyadmin-schoolbox \
	--net $(BRIDGE_NETWORK) \
	-e MYSQL_ROOT_PASSWORD=$(MYSQL_ROOT_PASSWORD) \
    -e PMA_HOST=$(MYSQL_SERVER) \
	-e PMA_PORT=3306 \
	-p 9093:80 \
	-d phpmyadmin/phpmyadmin

deleteall:
	@echo "Deleting all containers"
	@docker container rm $(shell docker ps -aq)

stopall:
	@echo "Stopping all containers"
	@docker stop $(shell docker ps -aq)
