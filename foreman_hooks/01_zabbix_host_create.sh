ZABBIX_SERVER="10.32.96.200"
USER="admin"
PASSWORD="redhat"

AUTH=$(curl -i -X POST -H 'Content-Type:application/json' -d \
	'{ 
		"jsonrpc": "2.0", 
		"method":"user.login", 
		"params": { 
			"user":"'${USER}'",
			 "password":"'${PASSWORD}'" 
		}, "id":1 
	}' http://${ZABBIX_SERVER}/zabbix/api_jsonrpc.php )

TOKEN=$(echo $AUTH  | awk -F "," '{print $3}' | awk -F ":" '{print $2}')

FQDN="${2}"
IP=$(hammer --output csv host list --search "name = ${FQDN}" | awk -F "," "(\$2 ~ /${FQDN}/) {print \$5}")
MAC=$(hammer --output csv host list --search "name = ${FQDN}" | awk -F "," "(\$2 ~ /${FQDN}/) {print \$6}")
MACA=$(echo ${MAC} | awk -F ":" '{print $1 $2 $3}')
MACB=$(echo ${MAC} | awk -F ":" '{print $4 $5 $6}')
#Group ID 7 = Linux server
#Template ID 10104 = Template ICMP Ping
#Template ID 10001 = Template OS Linux

# ---------- NOTICE -------------
# If the hook does fail make sure the IDs are the same in Zabbix otherwise adjust the IDs
# -------------------------------

curl -i -X POST -H 'Content-Type:application/json' -d \
'{    
    "jsonrpc": "2.0",
    "method": "host.create",
    "params": {
    "host": "'${FQDN}'",
    "interfaces": [
            {
                "type": 1,
                "main": 1,
                "useip": 1,
                "ip": "'${IP}'",
                "dns": "",
                "port": "10050"
            }
        ],
        "groups": [
            {
                "groupid": "7"
            }
        ],
        "templates": [
            {
                "templateid": "10104",
		"templateid": "10001"
            }
        ],
        "inventory": {
            "macaddress_a": "'${MACA}'",
            "macaddress_b": "'${MACB}'"
        }
    },
    "auth": '${TOKEN}',
    "id": 1
}' http://${ZABBIX_SERVER}/zabbix/api_jsonrpc.php
